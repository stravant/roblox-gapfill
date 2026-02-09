--!strict

local CoreGui = game:GetService("CoreGui")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService = game:GetService("UserInputService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)
local DraggerHandler = require(Packages.DraggerHandler)
local Signal = require(Packages.Signal)

local doFill = require(Src.doFill)
local copyPartProps = require(Src.copyPartProps)
local Settings = require("./Settings")

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

local function drawFace(parent: Instance, face: any, color: Color3, trans: number, zmod: number): { Instance }
	local scale = math.max(face.vertexMargin or 0, 0.15) / 8
	if scale > 0.2 then
		scale = 0.2
	end

	local segmentCFrame = CFrame.new(face.a, face.b) * CFrame.new(0, 0, -face.length/2)
	local tipLength = math.min(0.3 * face.length, scale * 15)
	local tipRadius = 0.5 * tipLength
	local shaftRadius = 0.5 * 0.5 * math.min(0.3 * face.length, scale * 7)

	local line = Instance.new('CylinderHandleAdornment')
	line.CFrame = segmentCFrame * CFrame.new(0, 0, tipLength/2) * CFrame.Angles(0, 0, math.pi/2)
	line.Adornee = workspace.Terrain
	line.ZIndex = 0 + zmod
	line.Height = face.length - tipLength
	line.Radius = shaftRadius
	line.Color3 = color
	line.Transparency = trans
	line.Parent = parent
	line.AlwaysOnTop = false

	local lineOnTop = line:Clone()
	lineOnTop.Parent = parent
	lineOnTop.Transparency = 0.7
	lineOnTop.AlwaysOnTop = true

	local head = Instance.new('ConeHandleAdornment')
	head.CFrame = segmentCFrame * CFrame.new(0, 0, -(face.length/2 - tipLength)) * CFrame.Angles(0, 0, math.pi/2)
	head.Adornee = workspace.Terrain
	head.ZIndex = 1 + zmod
	head.Height = tipLength
	head.Radius = tipRadius
	head.Color3 = color
	head.Transparency = trans
	head.Parent = parent
	head.AlwaysOnTop = false

	local headOnTop = head:Clone()
	headOnTop.Parent = parent
	headOnTop.Transparency = 0.7
	headOnTop.AlwaysOnTop = true

	return {line, head, lineOnTop, headOnTop}
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

local function mouseRaycast(): RaycastResult?
	local screenLoc = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ScreenPointToRay(screenLoc.X, screenLoc.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 9999)
end

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

local function startRecording(): string?
	return ChangeHistoryService:TryBeginRecording("GapFill", "GapFill Changes")
end
local function commitRecording(id: string)
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
end

local function createGapFillSession(plugin: Plugin, currentSettings: Settings.GapFillSettings)
	local session = {}
	local changeSignal = Signal.new()

	local draggerHandler = DraggerHandler.new(plugin)

	local mState: "EdgeA" | "EdgeB" = "EdgeA"
	local mEdgeA: any = nil
	local mEdgeADrawn: { Instance }? = nil

	local adornFolder = Instance.new("Folder")
	adornFolder.Name = "$GapFillAdornments"
	adornFolder.Archivable = false
	adornFolder.Parent = CoreGui

	-- Hover display
	local mHoverFaceDrawn: { Instance } = {}
	local function showHoverEdge(face: any)
		for _, ch in pairs(mHoverFaceDrawn) do
			ch:Destroy()
		end
		mHoverFaceDrawn = {}
		local color = if mState == "EdgeA" then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
		mHoverFaceDrawn = drawFace(adornFolder, face, color, 0, 2)
	end
	local function hideHoverEdge()
		for _, ch in pairs(mHoverFaceDrawn) do
			ch:Destroy()
		end
		mHoverFaceDrawn = {}
	end

	local function clearEdgeA()
		if mEdgeADrawn then
			for _, o in pairs(mEdgeADrawn) do
				o:Destroy()
			end
			mEdgeADrawn = nil
		end
		mEdgeA = nil
	end

	local function resetToEdgeA()
		clearEdgeA()
		mState = "EdgeA"
		changeSignal:Fire()
	end

	local function enableDragger(initialMouseDown: boolean?)
		if not draggerHandler:isEnabled() then
			hideHoverEdge()
			clearEdgeA()
			mState = "EdgeA"
			draggerHandler:enable(initialMouseDown)
			changeSignal:Fire()
		end
	end

	local function getThicknessOverride(): number?
		if currentSettings.ThicknessMode == "OneStud" then
			return 1
		elseif currentSettings.ThicknessMode == "Custom" then
			return currentSettings.CustomThickness
		elseif currentSettings.ThicknessMode == "Plate" then
			return 0.2
		elseif currentSettings.ThicknessMode == "Thinnest" then
			return 0.05
		else
			return nil
		end
	end

	local function getForceFactor(): number
		if currentSettings.FlipDirection then
			return -1
		else
			return 1
		end
	end

	local function tryUnionParts(parts: { BasePart }?)
		if not parts or #parts < 2 or not currentSettings.UnionResults then
			return
		end
		local first = parts[1]
		local rest = {}
		for i = 2, #parts do
			table.insert(rest, parts[i])
		end
		local ok, union = pcall(function()
			return first:UnionAsync(rest)
		end)
		if ok and union then
			union.Parent = first.Parent
			union.UsePartColor = true
			copyPartProps(first, union)
			for _, part in parts do
				part:Destroy()
			end
		end
	end

	local isOverUI = false
	local function updateHover()
		if isOverUI or draggerHandler:isEnabled() then
			hideHoverEdge()
			return
		end
		local result = mouseRaycast()
		if result and not result.Instance.Locked then
			local hoverEdge = getHoverEdge()
			if hoverEdge then
				showHoverEdge(hoverEdge)
			else
				hideHoverEdge()
			end
		else
			hideHoverEdge()
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
					mEdgeADrawn = drawFace(adornFolder, mEdgeA, Color3.new(1, 0, 0), 0, 0)
					mState = "EdgeB"
					changeSignal:Fire()
				end
			else
				-- EdgeB state — perform the fill
				-- Save edgeA before clearing visuals
				local savedEdgeA = mEdgeA

				-- Clear EdgeA visual adornments
				if mEdgeADrawn then
					for _, o in pairs(mEdgeADrawn) do
						o:Destroy()
					end
					mEdgeADrawn = nil
				end
				mEdgeA = nil
				mState = "EdgeA"
				hideHoverEdge()

				local hoverFace, theFace = getHoverEdge()
				if not hoverFace then
					changeSignal:Fire()
					return
				end

				local thicknessOverride = getThicknessOverride()
				local forceFactor = getForceFactor()

				local recording = startRecording()

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
						tryUnionParts(doFill(edge1, edge2, -1, thicknessOverride, forceFactor))
					elseif #theFace.vertices == 3 then
						local edge1 = prepEdge{
							a = theFace.vertices[1],
							b = theFace.vertices[2],
						}
						local edge2 = prepEdge{
							a = theFace.vertices[1],
							b = theFace.vertices[3],
						}
						tryUnionParts(doFill(edge1, edge2, -1, thicknessOverride, forceFactor))
					end
				else
					-- Different parts — normal fill
					tryUnionParts(doFill(savedEdgeA, hoverFace, 1, thicknessOverride, forceFactor))
				end

				if recording then
					commitRecording(recording)
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
				hideHoverEdge()
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
		hideHoverEdge()
		clearEdgeA()
		adornFolder:Destroy()
		draggerHandler:disable()
	end

	session.ChangeSignal = changeSignal
	session.GetEdgeState = function(): "EdgeA" | "EdgeB"
		return mState
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

	return session
end

export type GapFillSession = typeof(createGapFillSession(...))

return createGapFillSession
