--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService = game:GetService("UserInputService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)
local DraggerHandler = require(Packages.DraggerHandler)
local Signal = require(Packages.Signal)

local doFill = require(Src.doFill)
local Settings = require("./Settings")
local SessionUtils = require("./SessionUtils")
local EdgeArrow = require("./EdgeArrow")

type GeometryEdge = typeof(Geometry.getGeometry(...).edges[1])
type GeometryEdgeWithClick = GeometryEdge & {
	click: Vector3,
}
type GeometryFace = typeof(Geometry.getGeometry(...).faces[1])

local function edgeWithClick(edge: GeometryEdge, click: Vector3): GeometryEdgeWithClick
	local withClick = (edge :: any) :: GeometryEdgeWithClick
	withClick.click = click
	return withClick
end

local function getHoverEdgeSimple(hit: RaycastResult): (GeometryEdgeWithClick?, GeometryFace?)
	local point = hit.Position
	local geom = Geometry.getGeometry(hit.Instance, point)

	local bestEdge: GeometryEdgeWithClick? = nil
	local bestDist = math.huge

	for _, edge in pairs(geom.edges) do
		local dist = (point - edge.a - edge.direction*(point - edge.a):Dot(edge.direction)).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestEdge = edgeWithClick(edge, point)
		end
	end

	if bestEdge then
		bestEdge.click = point
		if (bestEdge.a - bestEdge.click).Magnitude < (bestEdge.b - bestEdge.click).Magnitude then
			bestEdge.a, bestEdge.b = bestEdge.b, bestEdge.a
			bestEdge.direction = -bestEdge.direction
		end
	end

	local bestFace = nil
	bestDist = math.huge

	for _, face in pairs(geom.faces) do
		local dist = math.abs((point - face.point):Dot(face.normal))
		if dist < bestDist then
			bestDist = dist
			bestFace = face
		end
	end

	return assert(bestEdge), bestFace
end

local mouseRaycast = SessionUtils.mouseRaycast

local function getPrimaryEdge(result: RaycastResult): (GeometryEdgeWithClick?, GeometryFace?)
	if result.Instance:IsA("MeshPart") or result.Instance:IsA("UnionOperation") then
		local edge = Geometry.blackboxFindClosestMeshEdge(result, workspace.CurrentCamera.CFrame.LookVector)
		if edge then
			return edgeWithClick(edge, result.Position), nil
		end
	end
	return getHoverEdgeSimple(result)
end

local function getHoverEdge(): (GeometryEdgeWithClick?, GeometryFace?)
	local result = mouseRaycast()
	if result then
		local primaryEdge, bestFace = getPrimaryEdge(result)
		return primaryEdge, bestFace
	else
		return nil, nil
	end
end

local function isCtrlHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local getCameraDepth = SessionUtils.getCameraDepth

local function edgesMatch(a: EdgeArrow.EdgeData?, b: EdgeArrow.EdgeData?): boolean
	if a == nil and b == nil then
		return true
	end
	if a == nil or b == nil then
		return false
	end
	return a.a == b.a and a.b == b.b
end

local function createGapFillSession(plugin: Plugin, currentSettings: Settings.GapFillSettings)
	local session = {}
	local changeSignal = Signal.new()

	local draggerHandler = DraggerHandler.new(plugin)

	local mState: "EdgeA" | "EdgeB" = "EdgeA"
	local mEdgeA: any = nil
	local mSurfaceNormal: Vector3? = nil
	local mHoverEdge: EdgeArrow.EdgeData? = nil

	local function clearEdgeA()
		mEdgeA = nil
		mSurfaceNormal = nil
	end

	local function resetToEdgeA()
		clearEdgeA()
		mHoverEdge = nil
		mState = "EdgeA"
		changeSignal:Fire()
	end

	local function enableDragger(initialMouseDown: boolean?)
		if not draggerHandler:isEnabled() then
			mHoverEdge = nil
			clearEdgeA()
			mState = "EdgeA"
			draggerHandler:enable(initialMouseDown)
			changeSignal:Fire()
		end
	end

	local function tryUnionParts(parts: { BasePart }?)
		SessionUtils.tryUnionParts(parts, currentSettings)
	end

	local isOverUI = false
	local function updateHover()
		if isOverUI or draggerHandler:isEnabled() then
			if mHoverEdge ~= nil then
				mHoverEdge = nil
				changeSignal:Fire()
			end
			return
		end
		local result = mouseRaycast()
		local newHoverEdge: EdgeArrow.EdgeData? = nil
		if result and not result.Instance.Locked then
			local hoverEdge = getHoverEdge()
			if hoverEdge then
				newHoverEdge = {
					a = hoverEdge.a,
					b = hoverEdge.b,
					length = hoverEdge.length,
					cameraDepth = getCameraDepth((hoverEdge.a + hoverEdge.b) / 2),
				}
			end
		end
		if not edgesMatch(mHoverEdge, newHoverEdge) then
			mHoverEdge = newHoverEdge
			changeSignal:Fire()
		end
	end

	local function handleClick()
		if draggerHandler:isEnabled() then
			return
		end
		if isCtrlHeld() then
			enableDragger(true)
			return
		end

		local result = mouseRaycast()
		if result and not result.Instance.Locked then
			if mState == "EdgeA" then
				local edge = getHoverEdge()
				if edge then
					mEdgeA = edge
					mSurfaceNormal = result.Normal
					mState = "EdgeB"
					changeSignal:Fire()
				end
			else
				-- EdgeB state — perform the fill
				-- Save edgeA before clearing
				local savedEdgeA = mEdgeA

				mEdgeA = nil
				mState = "EdgeA"
				mHoverEdge = nil

				local hoverFace, theFace = getHoverEdge()
				if not hoverFace then
					changeSignal:Fire()
					return
				end

				local thicknessOverride = SessionUtils.getThicknessOverride(currentSettings)
				local forceFactor = SessionUtils.getForceFactor(currentSettings)

				local recording = SessionUtils.startRecording("GapFill Changes")

				if theFace and savedEdgeA and savedEdgeA.part == hoverFace.part then
					-- Same part — extrude on the selected face
					local function prepEdge(edge: any)
						edge.length = (edge.b - edge.a).Magnitude
						edge.direction = (edge.b - edge.a).Unit
						edge.part = hoverFace.part
						edge.click = 0.25*edge.a + 0.75*edge.b
						return edge
					end
					if #theFace.vertices == 4 then
						local edge1 = prepEdge{
							a = theFace.vertices[1],
							b = theFace.vertices[2],
						}
						local edge2 = prepEdge{
							a = theFace.vertices[4],
							b = theFace.vertices[3],
						}
						tryUnionParts(doFill(edge1, edge2, -1, thicknessOverride, forceFactor, mSurfaceNormal))
					elseif #theFace.vertices == 3 then
						local edge1 = prepEdge{
							a = theFace.vertices[1],
							b = theFace.vertices[2],
						}
						local edge2 = prepEdge{
							a = theFace.vertices[1],
							b = theFace.vertices[3],
						}
						tryUnionParts(doFill(edge1, edge2, -1, thicknessOverride, forceFactor, mSurfaceNormal))
					end
				else
					-- Different parts — normal fill
					tryUnionParts(doFill(savedEdgeA, hoverFace, 1, thicknessOverride, forceFactor, mSurfaceNormal))
				end

				if recording then
					SessionUtils.commitRecording(recording)
				else
					warn("GapFill: ChangeHistory Recording failed, fall back to adding waypoint.")
					ChangeHistoryService:SetWaypoint("GapFill")
				end

				changeSignal:Fire()
			end
		else
			-- Clicked on nothing
			if mState == "EdgeB" then
				resetToEdgeA()
			end
		end
	end

	local function handleMouseUp()
		if draggerHandler:isEnabled() and not isCtrlHeld() then
			draggerHandler:disable()
			updateHover()
		end
	end

	local function handleIdle()
		if isCtrlHeld() then
			enableDragger()
		else
			if draggerHandler:isEnabled() then
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					draggerHandler:disable()
					updateHover()
				end
			else
				updateHover()
			end
		end
	end

	-- Input connections
	local inputChangedCn = UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			isOverUI = gameProcessed
		end
	end)

	local inputBeganCn: RBXScriptConnection? = nil
	local inputEndedCn: RBXScriptConnection? = nil
	local delayedBeginCn = task.delay(0, function()
		inputBeganCn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
				handleClick()
			end
		end)

		inputEndedCn = UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				handleMouseUp()
			end
		end)
	end)

	local cursorTargetTask = task.spawn(function()
		while true do
			handleIdle()
			task.wait()
		end
	end)

	local function teardown()
		inputChangedCn:Disconnect()
		if inputBeganCn then
			inputBeganCn:Disconnect()
		end
		if inputEndedCn then
			inputEndedCn:Disconnect()
		end
		task.cancel(delayedBeginCn)
		task.cancel(cursorTargetTask)
		draggerHandler:disable()
	end

	session.ChangeSignal = changeSignal
	session.GetEdgeState = function(): "EdgeA" | "EdgeB"
		return mState
	end
	session.GetHoverEdge = function(): EdgeArrow.EdgeData?
		return mHoverEdge
	end
	session.GetSelectedEdge = function(): EdgeArrow.EdgeData?
		if mEdgeA then
			return {
				a = mEdgeA.a,
				b = mEdgeA.b,
				length = mEdgeA.length,
				cameraDepth = getCameraDepth((mEdgeA.a + mEdgeA.b) / 2),
			}
		end
		return nil
	end
	session.GetSettings = function(): Settings.GapFillSettings
		return currentSettings
	end
	session.Update = function()
		-- Settings may have changed, nothing else to do
	end
	session.Destroy = function()
		teardown()
	end

	-- Test hooks (not for production use)
	session.TestSelectEdge = function(edge: any, edgeSurfaceNormal: Vector3)
		mEdgeA = edge
		mSurfaceNormal = edgeSurfaceNormal
		mState = "EdgeB"
		changeSignal:Fire()
	end
	session.TestResetEdge = function()
		resetToEdgeA()
	end

	return session
end

export type GapFillSession = typeof(createGapFillSession(...))

return createGapFillSession
