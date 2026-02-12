local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local doPolygonFill = require(script.Parent.doPolygonFill)
local TestHelpers = require(script.Parent.TestHelpers)

local makePart = TestHelpers.makePart
local collectCreatedParts = TestHelpers.collectCreatedParts

return function(t: TestContext)
	local cleanup: { Instance } = {}
	local function track(inst: Instance): Instance
		table.insert(cleanup, inst)
		return inst
	end
	local function cleanupAll()
		for _, inst in cleanup do
			inst:Destroy()
		end
		table.clear(cleanup)
	end

	--
	-- Triangle (3 vertices) creates WedgeParts
	--
	t.test("triangle creates WedgeParts", function()
		local refPart = makePart()
		track(refPart)

		local verts = {
			Vector3.new(0, 0, 0),
			Vector3.new(1, 0, 0),
			Vector3.new(0, 0, 1),
		}

		local created = collectCreatedParts(workspace, function()
			local result = doPolygonFill(verts, refPart, Vector3.yAxis, 0.2, 1, workspace)
			t.expect(result ~= nil).toBe(true)
		end)

		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p.Shape == Enum.PartType.Wedge then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Quad (4 vertices) creates more WedgeParts than triangle (fan = 2 triangles)
	--
	t.test("quad creates more WedgeParts than triangle", function()
		local refPart = makePart()
		track(refPart)

		local triVerts = {
			Vector3.new(0, 0, 0),
			Vector3.new(1, 0, 0),
			Vector3.new(0, 0, 1),
		}
		local triCreated = collectCreatedParts(workspace, function()
			doPolygonFill(triVerts, refPart, Vector3.yAxis, 0.2, 1, workspace)
		end)
		for _, p in triCreated do track(p) end
		local triCount = #triCreated

		local quadVerts = {
			Vector3.new(0, 0, 0),
			Vector3.new(1, 0, 0),
			Vector3.new(1, 0, 1),
			Vector3.new(0, 0, 1),
		}
		local quadCreated = collectCreatedParts(workspace, function()
			doPolygonFill(quadVerts, refPart, Vector3.yAxis, 0.2, 1, workspace)
		end)
		for _, p in quadCreated do track(p) end
		local quadCount = #quadCreated

		t.expect(quadCount > triCount).toBe(true)
		cleanupAll()
	end)

	--
	-- Thickness is respected
	--
	t.test("thickness is respected", function()
		local refPart = makePart()
		track(refPart)

		local verts = {
			Vector3.new(0, 0, 0),
			Vector3.new(2, 0, 0),
			Vector3.new(0, 0, 2),
		}
		local thickness = 0.25

		local created = collectCreatedParts(workspace, function()
			doPolygonFill(verts, refPart, Vector3.yAxis, thickness, 1, workspace)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do
			track(p)
			local minSize = math.min(p.Size.X, p.Size.Y, p.Size.Z)
			t.expect(math.abs(minSize - thickness) < 0.01).toBe(true)
		end
		cleanupAll()
	end)

	--
	-- Properties copied from reference part
	--
	t.test("copies properties from reference part", function()
		local refPart = makePart()
		refPart.Color = Color3.new(1, 0, 0)
		refPart.Material = Enum.Material.Neon
		track(refPart)

		local verts = {
			Vector3.new(0, 0, 0),
			Vector3.new(1, 0, 0),
			Vector3.new(0, 0, 1),
		}

		local created = collectCreatedParts(workspace, function()
			doPolygonFill(verts, refPart, Vector3.yAxis, 0.2, 1, workspace)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do
			track(p)
			t.expect(p.Color).toEqual(Color3.new(1, 0, 0))
			t.expect(p.Material).toBe(Enum.Material.Neon)
		end
		cleanupAll()
	end)

	--
	-- Force factor -1 produces different positions than 1
	--
	t.test("force factor -1 produces different positions than 1", function()
		local refPart = makePart()
		track(refPart)

		local verts = {
			Vector3.new(0, 0, 0),
			Vector3.new(2, 0, 0),
			Vector3.new(0, 0, 2),
		}

		local created1 = collectCreatedParts(workspace, function()
			doPolygonFill(verts, refPart, Vector3.yAxis, 0.2, 1, workspace)
		end)
		local positions1 = {}
		for _, p in created1 do
			track(p)
			table.insert(positions1, p.Position)
		end

		local created2 = collectCreatedParts(workspace, function()
			doPolygonFill(verts, refPart, Vector3.yAxis, 0.2, -1, workspace)
		end)
		local positions2 = {}
		for _, p in created2 do
			track(p)
			table.insert(positions2, p.Position)
		end

		t.expect(#positions1).toBe(#positions2)
		local anyDifferent = false
		for i = 1, #positions1 do
			if (positions1[i] - positions2[i]).Magnitude > 0.001 then
				anyDifferent = true
			end
		end
		t.expect(anyDifferent).toBe(true)
		cleanupAll()
	end)

	--
	-- Returns nil for < 3 vertices
	--
	t.test("returns nil for fewer than 3 vertices", function()
		local refPart = makePart()
		track(refPart)

		local result0 = doPolygonFill({}, refPart, Vector3.yAxis, 0.2, 1, workspace)
		t.expect(result0 == nil).toBe(true)

		local result2 = doPolygonFill({Vector3.zero, Vector3.xAxis}, refPart, Vector3.yAxis, 0.2, 1, workspace)
		t.expect(result2 == nil).toBe(true)

		cleanupAll()
	end)
end
