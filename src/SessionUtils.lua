--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UserInputService = game:GetService("UserInputService")

local Src = script.Parent

local copyPartProps = require(Src.copyPartProps)
local Settings = require("./Settings")

local SessionUtils = {}

function SessionUtils.mouseRaycast(): RaycastResult?
	local screenLoc = UserInputService:GetMouseLocation()
	local ray = workspace.CurrentCamera:ScreenPointToRay(screenLoc.X, screenLoc.Y)
	return workspace:Raycast(ray.Origin, ray.Direction * 9999)
end

function SessionUtils.getCameraDepth(point: Vector3): number
	local camera = workspace.CurrentCamera
	if camera then
		return math.abs(camera:WorldToViewportPoint(point).Z)
	else
		return 40
	end
end

function SessionUtils.getThicknessOverride(currentSettings: Settings.GapFillSettings): number?
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

function SessionUtils.getForceFactor(currentSettings: Settings.GapFillSettings): number
	if currentSettings.FlipDirection then
		return -1
	else
		return 1
	end
end

function SessionUtils.tryUnionParts(parts: { BasePart }?, currentSettings: Settings.GapFillSettings, referencePart: BasePart?): { BasePart }?
	if not parts or #parts < 2 or not currentSettings.UnionResults then
		return parts
	end
	local first = parts[1]
	local parent = first.Parent

	-- If we have a reference part, create a temp part aligned to its orientation
	-- to control the union's material direction. The temp part is placed outside
	-- the geometry's bounding box so it doesn't affect the shape, then subtracted
	-- away after the union.
	local tempPart: Part? = nil
	if referencePart then
		-- Compute bounding box of all parts to find a safe offset position
		local minPos = Vector3.new(math.huge, math.huge, math.huge)
		local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in parts do
			local pos = part.Position
			local halfSize = part.Size / 2
			minPos = Vector3.new(
				math.min(minPos.X, pos.X - halfSize.X),
				math.min(minPos.Y, pos.Y - halfSize.Y),
				math.min(minPos.Z, pos.Z - halfSize.Z)
			)
			maxPos = Vector3.new(
				math.max(maxPos.X, pos.X + halfSize.X),
				math.max(maxPos.Y, pos.Y + halfSize.Y),
				math.max(maxPos.Z, pos.Z + halfSize.Z)
			)
		end
		local center = (minPos + maxPos) / 2
		local extent = (maxPos - minPos).Magnitude / 2

		-- Place temp part offset from the geometry, aligned to reference orientation
		local refRotation = referencePart.CFrame - referencePart.CFrame.Position
		local tempSize = Vector3.new(0.05, 0.05, 0.05)
		local offsetPos = center + Vector3.new(extent + 2, 0, 0)

		tempPart = Instance.new("Part")
		tempPart.Size = tempSize
		tempPart.CFrame = refRotation + offsetPos
		tempPart.Anchored = true
	end

	local ok, union = pcall(function()
		if tempPart then
			-- Union with temp part first so it controls material direction
			return tempPart:UnionAsync(parts)
		else
			local rest = {}
			for i = 2, #parts do
				table.insert(rest, parts[i])
			end
			return first:UnionAsync(rest)
		end
	end)
	if ok and union then
		-- Subtract the temp part away if we used one
		if tempPart then
			-- Need to make sure the temp part is big enough to fully subtract
			tempPart.Size *= 2
			local subOk, subResult = pcall(function()
				return union:SubtractAsync({ tempPart :: Part })
			end)
			if subOk and subResult then
				union.Parent = nil
				union = subResult
			end
		end

		union.Parent = parent
		union.UsePartColor = true
		copyPartProps(first, union)
		for _, part in parts do
			part.Parent = nil
		end
		return { union }
	end
	return parts
end

function SessionUtils.startRecording(name: string): string?
	return ChangeHistoryService:TryBeginRecording("GapFill", name)
end

function SessionUtils.commitRecording(id: string)
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
end

return SessionUtils
