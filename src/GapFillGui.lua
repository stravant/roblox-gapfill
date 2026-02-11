local CoreGui = game:GetService("CoreGui")

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

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
local EdgeArrow = require("./EdgeArrow")
local VertexMarker = require("./VertexMarker")
local WireframeEdge = require("./WireframeEdge")

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
					Custom = e(ChipForToggle, {
						Text = "Custom",
						IsCurrent = current == "Custom",
						LayoutOrder = 1,
						OnClick = function()
							props.Settings.ThicknessMode = "Custom"
							props.UpdatedSettings()
						end,
					}),
					Thinnest = e(ChipForToggle, {
						Text = "Thinnest",
						IsCurrent = current == "Thinnest",
						LayoutOrder = 2,
						OnClick = function()
							props.Settings.ThicknessMode = "Thinnest"
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

local function UnionIsExpensiveWarning(props: {
	LayoutOrder: number?,
})
	return e("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "⚠️Filling using Unions instead of Wedges makes textures line up better but has performance costs, use with caution!",
		TextColor3 = Colors.WARNING_YELLOW,
		TextWrapped = true,
		Font = Enum.Font.SourceSansBold,
		TextSize = 13,
		LayoutOrder = props.LayoutOrder,
	})
end

local function OptionsPanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Advanced Options",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		UnionResults = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e(Checkbox, {
				Label = "Union results",
				Checked = props.Settings.UnionResults,
				Changed = function(newValue: boolean)
					props.Settings.UnionResults = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText =
					"When the fill requires more than one part, union the fill parts together into a single CSG part.\n" ..
					"<font color='#F5762A'>⚠️Loading unions has a significant upfront cost, so you must use many copies of a given union or need clean texturing to make that cost worth it over using separate wedges.</font>",
			}),
		}),
		Warning = props.Settings.UnionResults and e(UnionIsExpensiveWarning, {
			LayoutOrder = 2,
		}),
		ClassicUI = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 3,
			Subject = e(Checkbox, {
				Label = "Classic UI style",
				Checked = props.Settings.ClassicUI,
				Changed = function(newValue: boolean)
					props.Settings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Switch to something more similar to the classic GapFill UI.",
			}),
		}),
	})
end

local function PolygonActionButtons(props: {
	HandleAction: (string) -> (),
	VertexCount: number,
	LayoutOrder: number?,
})
	local canDone = props.VertexCount >= 3
	local canReset = props.VertexCount > 0
	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		DoneButton = e("Frame", {
			Size = UDim2.new(0.5, -2, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
		}, {
			Button = e(OperationButton, {
				Text = "Done",
				Color = Colors.ACTION_BLUE,
				Disabled = not canDone,
				Height = 30,
				OnClick = function()
					props.HandleAction("commitPolygon")
				end,
			}),
		}),
		ResetButton = e("Frame", {
			Size = UDim2.new(0.5, -2, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
		}, {
			Button = e(OperationButton, {
				Text = "Reset",
				Color = Colors.DARK_RED,
				Disabled = not canReset,
				Height = 30,
				OnClick = function()
					props.HandleAction("resetPolygon")
				end,
			}),
		}),
	})
end

local function FillModePanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	LayoutOrder: number?,
	EdgeState: "EdgeA" | "EdgeB",
	VertexCount: number,
})
	local current = props.Settings.FillMode
	local isPolygon = current == "Polygon"

	local statusText
	if isPolygon then
		if props.VertexCount == 0 then
			statusText = "Click part vertices to define a polygon."
		elseif props.VertexCount == 1 then
			statusText = "1 vertex selected. Click more vertices to define a polygon."
		elseif props.VertexCount < 3 then
			statusText = `{props.VertexCount} vertices selected. Click more vertices to define a polygon.`
		else
			statusText = `{props.VertexCount} vertices selected. Click the first vertex or press Done to complete.`
		end
	else
		if props.EdgeState == "EdgeA" then
			statusText = "Select the first edge of a gap to fill the space between."
		else
			statusText = "Select second edge of the gap, or click empty space to cancel."
		end
	end

	return e(SubPanel, {
		Title = "Fill Mode",
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
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				EdgeFill = e(ChipForToggle, {
					Text = "Edge Fill",
					IsCurrent = current == "Edge",
					LayoutOrder = 1,
					OnClick = function()
						props.Settings.FillMode = "Edge"
						props.UpdatedSettings()
					end,
				}),
				PolygonFill = e(ChipForToggle, {
					Text = "Polygon Fill",
					IsCurrent = current == "Polygon",
					LayoutOrder = 2,
					OnClick = function()
						props.Settings.FillMode = "Polygon"
						props.UpdatedSettings()
					end,
				}),
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText =
					"<b>Edge Fill</b> — Select two edges and fill the gap between them with wedge parts.\n" ..
					"<b>Polygon Fill</b> — Click a sequence of vertices to define a polygon, then fill it with wedge parts.",
			}),
		}),
		Status = props.Settings.HaveHelp and e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.GREY,
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 18,
			TextColor3 = Colors.WHITE,
			RichText = true,
			Text = `<i>{statusText}</i>`,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
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
		PolygonActions = isPolygon and e(PolygonActionButtons, {
			HandleAction = props.HandleAction,
			VertexCount = props.VertexCount,
			LayoutOrder = 3,
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
			Height = 30,
			OnClick = function()
				props.HandleAction("cancel")
			end,
		}),
	})
end

local function ClassicThicknessPanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local current = props.Settings.ThicknessMode
	local function makeButton(mode: typeof(props.Settings.ThicknessMode), label: string, subText: string, layoutOrder: number)
		local isCurrent = current == mode
		return e(OperationButton, {
			Text = label,
			SubText = subText,
			Color = if isCurrent then Colors.DARK_RED else Colors.GREY,
			Disabled = false,
			Height = 32,
			LayoutOrder = layoutOrder,
			OnClick = function()
				props.Settings.ThicknessMode = mode
				props.UpdatedSettings()
			end,
		})
	end
	return e(SubPanel, {
		Title = "Created Part Thickness",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		BestGuess = makeButton("BestGuess", "Best Guess", "match adjacent parts", 1),
		OneStud = makeButton("OneStud", "One Stud", "1.0 studs", 2),
		Plate = makeButton("Plate", "Plate", "0.2 studs", 3),
		Thinnest = makeButton("Thinnest", "Thinnest", "0.05 studs", 4),
	})
end

local function ClassicDirectionPanel(props: {
	Settings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	LayoutOrder: number?,
})
	local flipped = props.Settings.FlipDirection
	return e(SubPanel, {
		Title = "Direction Override",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		Default = e(OperationButton, {
			Text = "Default",
			Color = if not flipped then Colors.DARK_RED else Colors.GREY,
			Disabled = false,
			Height = 32,
			LayoutOrder = 1,
			OnClick = function()
				props.Settings.FlipDirection = false
				props.UpdatedSettings()
			end,
		}),
		Opposite = e(OperationButton, {
			Text = "Opposite",
			Color = if flipped then Colors.DARK_RED else Colors.GREY,
			Disabled = false,
			Height = 32,
			LayoutOrder = 2,
			OnClick = function()
				props.Settings.FlipDirection = true
				props.UpdatedSettings()
			end,
		}),
	})
end

local adornFolder = Instance.new("Folder")
adornFolder.Name = "$GapFillAdornments"
adornFolder.Archivable = false
adornFolder.Parent = CoreGui

local function AdornmentOverlay(props: {
	HoverEdge: EdgeArrow.EdgeData?,
	SelectedEdge: EdgeArrow.EdgeData?,
	EdgeState: "EdgeA" | "EdgeB",
	FillMode: Settings.FillMode,
	Vertices: { Vector3 }?,
	HoverVertex: Vector3?,
	IsNearFirstVertex: boolean,
})
	local children: { [string]: any } = {}

	if props.FillMode == "Polygon" then
		-- Polygon mode adornments
		local vertices = props.Vertices or {}
		local hoverVertex = props.HoverVertex

		-- Colors matching edge mode: red for selected, blue for hover
		local selectedColor = Color3.new(1, 0, 0)
		local hoverColor = Color3.new(0, 0, 1)

		-- Base scale for adornments
		local baseScale = 0.25
		local wireRadius = baseScale * 0.4

		-- Render selected vertex markers
		for i, vertex in vertices do
			children["Vertex" .. tostring(i)] = e(VertexMarker, {
				Position = vertex,
				Color = selectedColor,
				Radius = baseScale,
				ZIndexOffset = i, -- Ensure later vertices render on top
			})
		end

		-- Render wireframe edges between consecutive vertices
		for i = 1, #vertices - 1 do
			children["Edge" .. tostring(i)] = e(WireframeEdge, {
				From = vertices[i],
				To = vertices[i + 1],
				Color = selectedColor,
				Radius = wireRadius,
				ZIndexOffset = 1,
			})
		end

		-- Render hover vertex marker
		if hoverVertex then
			local thisHoverColor = if props.IsNearFirstVertex and #vertices >= 3
				then Color3.new(0, 1, 0)
				else hoverColor
			local hoverRadius = if props.IsNearFirstVertex and #vertices >= 3
				then baseScale * 1.8
				else baseScale
			children.HoverVertex = e(VertexMarker, {
				Position = hoverVertex,
				Color = thisHoverColor,
				Radius = hoverRadius,
				ZIndexOffset = 4,
			})

			-- Wireframe from last vertex to hover
			if #vertices >= 1 then
				children.HoverEdgeFromLast = e(WireframeEdge, {
					From = vertices[#vertices],
					To = hoverVertex,
					Color = hoverColor,
					Radius = wireRadius,
					ZIndexOffset = 2,
				})
			end

			-- Wireframe from hover back to first vertex (closing edge preview)
			if #vertices >= 2 then
				children.HoverEdgeToFirst = e(WireframeEdge, {
					From = hoverVertex,
					To = vertices[1],
					Color = hoverColor,
					Radius = wireRadius,
					ZIndexOffset = 2,
				})
			end
		end
	else
		-- Edge mode adornments (existing behavior)
		if props.SelectedEdge then
			children.SelectedEdge = e(EdgeArrow, {
				Edge = props.SelectedEdge,
				Color = Color3.new(1, 0, 0),
				ZIndexOffset = 0,
			})
		end
		if props.HoverEdge then
			local hoverColor = if props.EdgeState == "EdgeA" then Color3.new(1, 0, 0) else Color3.new(0, 0, 1)
			children.HoverEdge = e(EdgeArrow, {
				Edge = props.HoverEdge,
				Color = hoverColor,
				ZIndexOffset = 2,
			})
		end
	end

	return ReactRoblox.createPortal(children, adornFolder)
end

local function ClassicContent(props: {
	CurrentSettings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	return React.createElement(React.Fragment, nil, {
		ClassicDirectionPanel = e(ClassicDirectionPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		ClassicThicknessPanel = e(ClassicThicknessPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		OptionsPanel = e(SubPanel, {
			Title = "Advanced Options",
			LayoutOrder = nextOrder(),
			Padding = UDim.new(0, 4),
		}, {
			ReturnToNewUI = e(Checkbox, {
				LayoutOrder = nextOrder(),
				Label = "Classic UI style",
				Checked = currentSettings.ClassicUI,
				Changed = function(newValue: boolean)
					currentSettings.ClassicUI = newValue
					props.UpdatedSettings()
				end,
			}),
		}),
	})
end

local function ModernContent(props: {
	CurrentSettings: Settings.GapFillSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	EdgeState: "EdgeA" | "EdgeB",
	Vertices: { Vector3 }?,
})
	local currentSettings = props.CurrentSettings
	local nextOrder = createNextOrder()
	local vertexCount = if props.Vertices then #props.Vertices else 0
	return React.createElement(React.Fragment, nil, {
		FillModePanel = e(FillModePanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			EdgeState = props.EdgeState,
			VertexCount = vertexCount,
			LayoutOrder = nextOrder(),
		}),
		ThicknessPanel = e(ThicknessPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		DirectionPanel = e(DirectionPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		OptionsPanel = e(OptionsPanel, {
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			LayoutOrder = nextOrder(),
		}),
		CloseButton = e(CloseButton, {
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
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
	HoverEdge: EdgeArrow.EdgeData?,
	SelectedEdge: EdgeArrow.EdgeData?,
	-- Polygon mode props
	Vertices: { Vector3 }?,
	HoverVertex: Vector3?,
	IsNearFirstVertex: boolean?,
})
	local currentSettings = props.CurrentSettings
	return e(PluginGui, {
		Config = GAPFILL_CONFIG,
		State = {
			Mode = props.GuiState,
			Settings = currentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
		AdornmentOverlay = e(AdornmentOverlay, {
			HoverEdge = props.HoverEdge,
			SelectedEdge = props.SelectedEdge,
			EdgeState = props.EdgeState,
			FillMode = currentSettings.FillMode,
			Vertices = props.Vertices,
			HoverVertex = props.HoverVertex,
			IsNearFirstVertex = props.IsNearFirstVertex or false,
		}),
		Content = if currentSettings.ClassicUI
			then e(ClassicContent, {
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
			})
			else e(ModernContent, {
				CurrentSettings = currentSettings,
				UpdatedSettings = props.UpdatedSettings,
				HandleAction = props.HandleAction,
				EdgeState = props.EdgeState,
				Vertices = props.Vertices,
			}),
	})
end

return GapFillGui
