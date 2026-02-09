local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local HelpGui = require("./PluginGui/HelpGui")
local SubPanel = require("./PluginGui/SubPanel")
local PluginGui = require("./PluginGui/PluginGui")
local OperationButton = require("./PluginGui/OperationButton")
local ChipForToggle = require("./PluginGui/ChipForToggle")
local Checkbox = require("./PluginGui/Checkbox")
local NumberInput = require("./PluginGui/NumberInput")
local Settings = require("./Settings")
local PluginGuiTypes = require("./PluginGui/Types")

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

local function DirectionPanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Direction Override",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Content = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e(Checkbox, {
				Label = "Generate on other side",
				Checked = props.Settings.FlipDirection,
				Changed = function(newValue: boolean)
					props.Settings.FlipDirection = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "GapFill tries to make the generated parts flush with the the adjacent surfaces. Force the generated parts the other way if GapFill guessed wrong.",
				HelpImage = "rbxassetid://119701792475192",
				HelpImageAspectRatio = 1.9,
			}),
		}),
	})
end

local function ThicknessPanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ThicknessMode
	return e(SubPanel, {
		Title = "Created Part Thickness",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Buttons = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				Row1 = e("Frame", {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}, {
					ListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					BestGuess = e(ChipForToggle, {
						Text = "Best Guess",
						IsCurrent = current == "BestGuess",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ThicknessMode = "BestGuess"
							props.UpdatedSettings()
						end,
					}),
					OneStud = e(ChipForToggle, {
						Text = "One Stud",
						IsCurrent = current == "OneStud",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ThicknessMode = "OneStud"
							props.UpdatedSettings()
						end,
					}),
				}),
				Row2 = e("Frame", {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}, {
					ListLayout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Thinnest = e(ChipForToggle, {
						Text = "Thinnest",
						IsCurrent = current == "Thinnest",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ThicknessMode = "Thinnest"
							props.UpdatedSettings()
						end,
					}),
					Custom = e(ChipForToggle, {
						Text = "Custom",
						IsCurrent = current == "Custom",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ThicknessMode = "Custom"
							props.UpdatedSettings()
						end,
					}),
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText =
					"How thick to make the created parts:\n" ..
					"<b>•Best Guess</b> — Match the thickness of parts adjacent to the edges.\n" ..
					"<b>•One Stud</b> — Exactly 1 stud.\n" ..
					"<b>•Thinnest</b> — 0.05 studs (thinner is possible but may cause physics issues).\n" ..
					"<b>•Custom</b> — enter a specific value below.",
			}),
		}),
		CustomInput = current == "Custom" and e(HelpGui.WithHelpIcon, {
			LayoutOrder = 2,
			Subject = e(NumberInput, {
				Label = "Thickness",
				Unit = " studs",
				Value = props.Settings.CustomThickness,
				ValueEntered = function(newValue: number)
					if newValue > 0 then
						props.Settings.CustomThickness = newValue
						props.UpdatedSettings()
						return newValue
					end
					return nil
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "The thickness in studs for the created parts. Must be greater than 0.",
			}),
		}),
	})
end

local function StatusDisplay(props: {
	EdgeState: "EdgeA" | "EdgeB",
	LayoutOrder: number?,
})
	local text = if props.EdgeState == "EdgeA"
		then "Select first edge of gap to fill the space between."
		else "Select second edge, or click empty space to cancel."
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Label = e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.GREY,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = Colors.WHITE,
			RichText = true,
			Text = `<i>{text}</i>`,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
	})
end

local function CloseButton(props: {
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		CancelButton = e(OperationButton, {
			Text = "Close <i>GapFill</i>",
			Color = Colors.DARK_RED,
			Disabled = false,
			Height = 34,
			OnClick = function()
				props.HandleAction("cancel")
			end,
		}),
	})
end

local GAPFILL_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "GapFill",
	PendingText = "...",
	TutorialElement = nil,
}

local function GapFillGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CurrentSettings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	EdgeState: "EdgeA" | "EdgeB",
})
	local currentSettings = props.CurrentSettings
	local updatedSettings = props.UpdatedSettings
	local nextOrder = createNextOrder()
	return e(PluginGui, {
		Config = GAPFILL_CONFIG,
		State = {
			Mode = props.GuiState,
			Settings = currentSettings,
			UpdatedSettings = updatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
		-- Only show the status for new users who haven't disabled the help
		StatusDisplay = currentSettings.HaveHelp and e(StatusDisplay, {
			EdgeState = props.EdgeState,
			LayoutOrder = nextOrder(),
		}),
		ThicknessPanel = e(ThicknessPanel, {
			Settings = currentSettings,
			UpdatedSettings = updatedSettings,
			LayoutOrder = nextOrder(),
		}),
		DirectionPanel = e(DirectionPanel, {
			Settings = currentSettings,
			UpdatedSettings = updatedSettings,
			LayoutOrder = nextOrder(),
		}),
		CloseButton = e(CloseButton, {
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
	})
end

return GapFillGui
