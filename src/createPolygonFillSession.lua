--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService = game:GetService("UserInputService")

local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)
local Signal = require(Packages.Signal)

local doPolygonFill = require(Src.doPolygonFill)
local createVirtualUndo = require("./createVirtualUndo")
local Settings = require("./Settings")
local SessionUtils = require("./SessionUtils")

type GeometryEdge = typeof(Geometry.getGeometry(...).edges[1])

local mouseRaycast = SessionUtils.mouseRaycast

local function getClosestVertex(hit: RaycastResult): (Vector3?, BasePart?)
	local point = hit.Position
	local part = hit.Instance :: BasePart
	
	local edge = Geometry.blackboxFindClosestMeshEdge(hit, workspace.CurrentCamera.CFrame.LookVector)
	if edge then
		local v1, v2 = edge.a, edge.b
		if (point - v1).Magnitude < (point - v2).Magnitude then
			return v1, part
		else
			return v2, part
		end
	else
		return nil, nil
	end
end

local getCameraDepth = SessionUtils.getCameraDepth

local function verticesMatch(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 0.001
end

local function createPolygonFillSession(plugin: Plugin, currentSettings: Settings.GapFillSettings)
	local session = {}
	local changeSignal = Signal.new()
	local virtualUndo = createVirtualUndo("GapFill polygon vertex", "GapFillPolygonUndoWaypoint")

	local vertices: { Vector3 } = {}
	local referencePart: BasePart? = nil
	local surfaceNormal: Vector3? = nil
	local hoverVertex: Vector3? = nil
	local isNearFirst = false

	local function resetVertices()
		if #vertices > 0 then
			virtualUndo.uninstall()
		end
		vertices = {}
		referencePart = nil
		surfaceNormal = nil
		isNearFirst = false
		changeSignal:Fire()
	end

	local function commitPolygon()
		if #vertices < 3 then
			return
		end

		local refPart = referencePart
		if not refPart then
			return
		end

		virtualUndo.uninstall()

		local recording = SessionUtils.startRecording("Polygon Fill")

		-- Polygon mode can't infer thickness from geometry like edge mode can,
		-- so default BestGuess to 0.2 studs
		local thickness = SessionUtils.getThicknessOverride(currentSettings) or 0.2
		local forceFactor = SessionUtils.getForceFactor(currentSettings)
		local parent = refPart.Parent or workspace

		local parts = doPolygonFill(vertices, refPart, surfaceNormal, thickness, forceFactor, parent)
		SessionUtils.tryUnionParts(parts, currentSettings)

		if recording then
			SessionUtils.commitRecording(recording)
		else
			warn("GapFill: ChangeHistory Recording failed, fall back to adding waypoint.")
			ChangeHistoryService:SetWaypoint("Polygon Fill")
		end

		resetVertices()
	end

	local function checkNearFirstVertex(vertex: Vector3): boolean
		if #vertices < 3 then
			return false
		end
		local firstVertex = vertices[1]
		local depth = getCameraDepth(firstVertex)
		local threshold = depth / 80 -- Scale threshold with camera distance
		return (vertex - firstVertex).Magnitude < threshold
	end

	local isOverUI = false
	local function updateHover()
		if isOverUI then
			if hoverVertex ~= nil then
				hoverVertex = nil
				isNearFirst = false
				changeSignal:Fire()
			end
			return
		end
		local result = mouseRaycast()
		local newHoverVertex: Vector3? = nil
		local newIsNearFirst = false
		if result and not result.Instance.Locked then
			local vertex, _ = getClosestVertex(result)
			if vertex then
				newHoverVertex = vertex
				newIsNearFirst = checkNearFirstVertex(vertex)
			end
		end
		local changed = false
		if hoverVertex ~= newHoverVertex then
			changed = true
		end
		if isNearFirst ~= newIsNearFirst then
			changed = true
		end
		if changed then
			hoverVertex = newHoverVertex
			isNearFirst = newIsNearFirst
			changeSignal:Fire()
		end
	end

	local function handleClick()
		if isOverUI then
			return
		end

		local result = mouseRaycast()
		if result and not result.Instance.Locked then
			local vertex, part = getClosestVertex(result)
			if vertex and part then
				-- Check if clicking near the first vertex to complete
				if #vertices >= 3 and checkNearFirstVertex(vertex) then
					commitPolygon()
					return
				end

				-- Skip duplicate vertex, or if we have enough treat it as
				-- completing the polygon.
				if #vertices > 0 and verticesMatch(vertex, vertices[#vertices]) then
					if #vertices >= 3 then
						commitPolygon()
					end
					return
				end

				-- Add vertex
				table.insert(vertices, vertex)
				if referencePart == nil then
					referencePart = part :: BasePart
					surfaceNormal = result.Normal
				end
				virtualUndo.install()
				changeSignal:Fire()
			end
		else
			-- Clicked on nothing: remove last vertex
			if #vertices > 0 then
				table.remove(vertices, #vertices)
				if #vertices == 0 then
					referencePart = nil
					virtualUndo.uninstall()
				end
				changeSignal:Fire()
			end
		end
	end

	local function handleIdle()
		updateHover()
	end

	-- Input connections
	local inputChangedCn = UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			isOverUI = gameProcessed
		end
	end)

	local inputBeganCn: RBXScriptConnection? = nil
	local delayedBeginCn = task.delay(0, function()
		inputBeganCn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
				handleClick()
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
		task.cancel(delayedBeginCn)
		task.cancel(cursorTargetTask)
	end

	session.ChangeSignal = changeSignal
	session.GetVertices = function(): { Vector3 }
		return vertices
	end
	session.GetHoverVertex = function(): Vector3?
		return hoverVertex
	end
	session.GetIsNearFirstVertex = function(): boolean
		return isNearFirst
	end
	session.GetReferencePart = function(): BasePart?
		return referencePart
	end
	session.GetSettings = function(): Settings.GapFillSettings
		return currentSettings
	end
	session.CommitPolygon = function()
		commitPolygon()
	end
	session.ResetVertices = function()
		resetVertices()
	end
	session.Undo = function(waypointName: string): boolean
		return virtualUndo.handleUndo(waypointName, function()
			if #vertices > 0 then
				table.remove(vertices, #vertices)
				if #vertices == 0 then
					referencePart = nil
				end
				changeSignal:Fire()
			end
			return #vertices > 0
		end)
	end
	session.Update = function()
		-- Settings may have changed, nothing else to do
	end
	session.Destroy = function()
		if #vertices > 0 then
			virtualUndo.uninstall()
		end
		teardown()
	end

	-- Test hooks (not for production use)
	session.TestAddVertex = function(vertex: Vector3, part: BasePart, normal: Vector3?)
		table.insert(vertices, vertex)
		if referencePart == nil then
			referencePart = part
			surfaceNormal = normal
		end
		virtualUndo.install()
		changeSignal:Fire()
	end
	session.TestRemoveLastVertex = function()
		if #vertices > 0 then
			table.remove(vertices, #vertices)
			if #vertices == 0 then
				referencePart = nil
				virtualUndo.uninstall()
			end
			changeSignal:Fire()
		end
	end
	-- Set state directly without virtualUndo (avoids ChangeHistory yield in tests)
	session.TestSetState = function(verts: { Vector3 }, refPart: BasePart?, normal: Vector3?)
		vertices = verts
		referencePart = refPart
		surfaceNormal = normal
		changeSignal:Fire()
	end

	return session
end

export type PolygonFillSession = typeof(createPolygonFillSession(...))

return createPolygonFillSession
