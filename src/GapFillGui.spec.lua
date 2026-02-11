local CoreGui = game:GetService("CoreGui")

local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local Packages = script.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local GapFillGui = require(script.Parent.GapFillGui)

local e = React.createElement

local function makeTestSettings()
	return {
		WindowPosition = Vector2.zero,
		WindowAnchor = Vector2.zero,
		WindowHeightDelta = 0,
		DoneTutorial = false,
		HaveHelp = false,
		FlipDirection = false,
		ThicknessMode = "OneStud",
		CustomThickness = 0.2,
		UnionResults = false,
		ClassicUI = false,
		FillMode = "Edge",
	}
end

local function mountAndUnmount(settings: {
	FillMode: "Edge" | "Polygon",
})
	local screen = Instance.new("ScreenGui")
	screen.Name = "GapFillGuiTest"
	screen.Parent = CoreGui

	local root = ReactRoblox.createRoot(screen)
	ReactRoblox.act(function()
		root:render(e(GapFillGui, {
			GuiState = "active",
			CurrentSettings = makeTestSettings(),
			UpdatedSettings = function() end,
			HandleAction = function() end,
			Panelized = false,
			EdgeState = "EdgeA",
			HoverEdge = nil,
			SelectedEdge = nil,
			Vertices = nil,
			HoverVertex = nil,
			IsNearFirstVertex = false,
		}))
	end)

	ReactRoblox.act(function()
		root:unmount()
	end)
	screen:Destroy()
end

return function(t: TestContext)
	t.test("Edge mode smoke", function()
		mountAndUnmount({ FillMode = "Edge" })
	end)
	t.test("Polygon mode smoke", function()
		mountAndUnmount({ FillMode = "Polygon" })
	end)
end
