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

function SessionUtils.tryUnionParts(parts: { BasePart }?, currentSettings: Settings.GapFillSettings)
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

function SessionUtils.startRecording(name: string): string?
	return ChangeHistoryService:TryBeginRecording("GapFill", name)
end

function SessionUtils.commitRecording(id: string)
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Commit)
end

return SessionUtils
