local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "gapFillState"

local PluginGuiTypes = require("./PluginGui/Types")

export type GapFillSettings = PluginGuiTypes.PluginGuiSettings & {
	FlipDirection: boolean,
	ThicknessMode: "BestGuess" | "OneStud" | "Custom" | "Thinnest" | "Plate",
	CustomThickness: number,
	UnionResults: boolean,
	ClassicUI: boolean,
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

		FlipDirection = if raw.FlipDirection ~= nil then raw.FlipDirection else false,
		ThicknessMode = if raw.ThicknessMode ~= nil then raw.ThicknessMode else "BestGuess",
		CustomThickness = if raw.CustomThickness ~= nil then raw.CustomThickness else 0.2,
		UnionResults = if raw.UnionResults ~= nil then raw.UnionResults else false,
		ClassicUI = if raw.ClassicUI ~= nil then raw.ClassicUI else false,
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

		FlipDirection = settings.FlipDirection,
		ThicknessMode = settings.ThicknessMode,
		CustomThickness = settings.CustomThickness,
		UnionResults = settings.UnionResults,
		ClassicUI = settings.ClassicUI,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}
