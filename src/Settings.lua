local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "gapFillState"

local PluginGuiTypes = require("./PluginGui/Types")

export type GapFillSettings = PluginGuiTypes.PluginGuiSettings & {
	DirectionMode: "Default" | "Negative",
	ThicknessMode: "BestGuess" | "OneStud" | "Plate" | "Thinnest",
}

local function loadSettings(plugin: Plugin): GapFillSettings
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowAnchor = Vector2.new(
			raw.WindowAnchorX or 0,
			raw.WindowAnchorY or 0
		),
		WindowHeightDelta = if raw.WindowHeightDelta ~= nil then raw.WindowHeightDelta else 0,
		DoneTutorial = if raw.DoneTutorial ~= nil then raw.DoneTutorial else false,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,

		----

		DirectionMode = if raw.DirectionMode ~= nil then raw.DirectionMode else "Default",
		ThicknessMode = if raw.ThicknessMode ~= nil then raw.ThicknessMode else "BestGuess",
	}
end
local function saveSettings(plugin: Plugin, settings: GapFillSettings)
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowAnchorX = settings.WindowAnchor.X,
		WindowAnchorY = settings.WindowAnchor.Y,
		WindowHeightDelta = settings.WindowHeightDelta,
		DoneTutorial = settings.DoneTutorial,
		HaveHelp = settings.HaveHelp,

		----

		DirectionMode = settings.DirectionMode,
		ThicknessMode = settings.ThicknessMode,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}
