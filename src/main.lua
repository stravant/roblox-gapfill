--!strict
local CoreGui = game:GetService("CoreGui")

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Signal = require(Packages.Signal)

local createGapFillSession = require("./createGapFillSession")
local createPolygonFillSession = require("./createPolygonFillSession")
local Settings = require("./Settings")
local GapFillGui = require("./GapFillGui")
local PluginGuiTypes = require("./PluginGui/Types")

return function(plugin: Plugin, panel: DockWidgetPluginGui, buttonClicked: Signal.Signal<>, setButtonActive: (active: boolean) -> ())
	local edgeSession: createGapFillSession.GapFillSession? = nil
	local polySession: createPolygonFillSession.PolygonFillSession? = nil

	local active = false

	local activeSettings = Settings.Load(plugin)

	local pluginActive = false

	local reactRoot: ReactRoblox.RootType? = nil
	local reactScreenGui: LayerCollector? = nil

	local handleAction: (string) -> () = nil

	local function destroyReactRoot()
		if reactRoot then
			reactRoot:unmount()
			reactRoot = nil
		end
		if reactScreenGui then
			reactScreenGui:Destroy()
			reactScreenGui = nil
		end
	end
	local function createReactRoot()
		if panel.Enabled then
			reactRoot = ReactRoblox.createRoot(panel)
		else
			local screen = Instance.new("ScreenGui")
			screen.Name = "GapFillMainGui"
			screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			screen.Parent = CoreGui
			reactScreenGui = screen
			reactRoot = ReactRoblox.createRoot(screen)
		end
	end

	local function getGuiState(): PluginGuiTypes.PluginGuiMode
		if not active then
			return "inactive"
		else
			return "active"
		end
	end

	local function getEdgeState(): "EdgeA" | "EdgeB"
		if edgeSession then
			return edgeSession.GetEdgeState()
		end
		return "EdgeA"
	end

	local ensureCorrectSession;

	local function updateUI()
		local needsUI = active or panel.Enabled
		if needsUI then
			if not reactRoot then
				createReactRoot()
			elseif panel.Enabled and reactScreenGui ~= nil then
				destroyReactRoot()
				createReactRoot()
			elseif not panel.Enabled and reactScreenGui == nil then
				destroyReactRoot()
				createReactRoot()
			end

			assert(reactRoot, "We just created it")
			reactRoot:render(React.createElement(GapFillGui, {
				GuiState = getGuiState(),
				CurrentSettings = activeSettings,
				UpdatedSettings = function()
					if edgeSession then
						edgeSession.Update()
					end
					if polySession then
						polySession.Update()
					end
					if active then
						ensureCorrectSession()
					end
					updateUI()
				end,
				HandleAction = handleAction,
				Panelized = panel.Enabled,
				-- Edge mode props
				EdgeState = getEdgeState(),
				HoverEdge = if edgeSession then edgeSession.GetHoverEdge() else nil,
				SelectedEdge = if edgeSession then edgeSession.GetSelectedEdge() else nil,
				-- Polygon mode props
				Vertices = if polySession then polySession.GetVertices() else nil,
				HoverVertex = if polySession then polySession.GetHoverVertex() else nil,
				IsNearFirstVertex = if polySession then polySession.GetIsNearFirstVertex() else false,
			}))
		elseif reactRoot then
			destroyReactRoot()
		end
	end

	local function destroySession()
		if edgeSession then
			edgeSession.Destroy()
			edgeSession = nil
		end
		if polySession then
			polySession.Destroy()
			polySession = nil
		end
	end

	function ensureCorrectSession()
		if activeSettings.FillMode == "Polygon" then
			if edgeSession then
				edgeSession.Destroy()
				edgeSession = nil
			end
			if not polySession then
				local newSession = createPolygonFillSession(plugin, activeSettings)
				newSession.ChangeSignal:Connect(updateUI)
				polySession = newSession
			end
		else
			if polySession then
				polySession.Destroy()
				polySession = nil
			end
			if not edgeSession then
				local newSession = createGapFillSession(plugin, activeSettings)
				newSession.ChangeSignal:Connect(updateUI)
				edgeSession = newSession
			end
		end
	end

	local function setActive(newActive: boolean)
		if active == newActive then
			return
		end
		setButtonActive(newActive)
		active = newActive
		if newActive then
			-- Activate plugin and create session
			if not pluginActive then
				plugin:Activate(true)
				pluginActive = true
			end
			ensureCorrectSession()
		else
			destroySession()
		end
		updateUI()
	end

	local function closeRequested()
		setActive(false)
		plugin:Deactivate()
	end

	local function doReset()
		destroySession()
		setActive(true)
	end

	function handleAction(action: string)
		if action == "cancel" then
			closeRequested()
		elseif action == "reset" then
			doReset()
		elseif action == "togglePanelized" then
			panel.Enabled = not panel.Enabled
			updateUI()
		elseif action == "commitPolygon" then
			if polySession then
				polySession.CommitPolygon()
			end
		elseif action == "resetPolygon" then
			if polySession then
				polySession.ResetVertices()
			end
		else
			warn("GapFill: Unknown action: "..action)
		end
	end

	local clickedCn = buttonClicked:Connect(function()
		if active then
			setActive(false)
		else
			doReset()
		end
	end)

	-- Initial UI show in the case where we're in Panelized mode
	updateUI()

	plugin.Deactivation:Connect(function()
		pluginActive = false
		setActive(false)
	end)

	plugin.Unloading:Connect(function()
		destroySession()
		setActive(false)
		destroyReactRoot()
		Settings.Save(plugin, activeSettings)
		clickedCn:Disconnect()
	end)
end
