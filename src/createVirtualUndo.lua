--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local function createVirtualUndo(waypointName: string, attributeName: string)
	local installed = false

	local function addWaypointInternal()
		ServerStorage:SetAttribute(attributeName, math.random())
		ChangeHistoryService:SetWaypoint(waypointName)
	end

	local function install()
		if installed then
			return
		end
		addWaypointInternal()
		installed = true
	end

	local function uninstall()
		if not installed then
			return
		end
		ServerStorage:SetAttribute(attributeName, nil)
		if not ChangeHistoryService:GetCanUndo() then
			return
		end
		local thisTask = nil
		local foundWaypointName = nil
		ChangeHistoryService.OnUndo:Once(function(name: string)
			foundWaypointName = name
			if thisTask then
				coroutine.resume(thisTask)
			end
		end)
		ChangeHistoryService:Undo()
		if not foundWaypointName then
			thisTask = coroutine.running()
			local completed = false
			task.delay(0.1, function()
				if completed then
					return
				end
				foundWaypointName = waypointName
				coroutine.resume(thisTask)
			end)
			coroutine.yield()
			completed = true
		end
		if foundWaypointName ~= waypointName then
			ChangeHistoryService:Redo()
		end
		installed = false
	end

	-- Handle an OnUndo event. If the waypoint is ours, calls undoCallback
	-- which should return true if there are more items to undo (a fresh
	-- virtual waypoint will be added). Returns true if we handled the undo.
	local function handleUndo(undoWaypointName: string, undoCallback: () -> boolean): boolean
		if undoWaypointName ~= waypointName then
			return false
		end
		local hasMore = undoCallback()
		if hasMore then
			addWaypointInternal()
		end
		return true
	end

	return {
		install = install,
		uninstall = uninstall,
		handleUndo = handleUndo,
	}
end

export type VirtualUndo = typeof(createVirtualUndo(...))

return createVirtualUndo
