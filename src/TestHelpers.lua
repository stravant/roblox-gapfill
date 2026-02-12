local Settings = require("./Settings")

local TestHelpers = {}

function TestHelpers.makePart(position: Vector3?, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size or Vector3.new(1, 1, 1)
	part.Position = position or Vector3.zero
	part.Parent = workspace
	return part
end

function TestHelpers.makeEdge(a: Vector3, b: Vector3, part: BasePart, click: Vector3?, inferred: boolean?)
	local dir = (b - a).Unit
	return {
		a = a,
		b = b,
		direction = dir,
		length = (b - a).Magnitude,
		part = part,
		click = click or (a + b) / 2,
		inferred = inferred or false,
	}
end

-- Collect all parts that were created as children of a parent during a callback
function TestHelpers.collectCreatedParts(parent: Instance, fn: () -> ()): { BasePart }
	local before = {}
	for _, child in parent:GetChildren() do
		before[child] = true
	end
	fn()
	local created = {}
	for _, child in parent:GetChildren() do
		if not before[child] and child:IsA("BasePart") then
			table.insert(created, child)
		end
	end
	return created
end

function TestHelpers.makeTestSettings(overrides: { [string]: any }?): Settings.GapFillSettings
	local settings = {
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
	if overrides then
		for key, value in overrides do
			(settings :: any)[key] = value
		end
	end
	return settings
end

return TestHelpers
