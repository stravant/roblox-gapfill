local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local createPolygonFillSession = require(script.Parent.createPolygonFillSession)

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
		FillMode = "Polygon",
	}
end

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
	-- Starts with empty vertices
	--
	t.test("starts with empty vertices", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		t.expect(#session.GetVertices()).toBe(0)
		t.expect(session.GetReferencePart() == nil).toBe(true)
		session.Destroy()
	end)

	--
	-- TestAddVertex accumulates vertices correctly
	--
	t.test("TestAddVertex accumulates vertices", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		session.TestAddVertex(Vector3.new(0, 0, 0), part, Vector3.yAxis)
		t.expect(#session.GetVertices()).toBe(1)

		session.TestAddVertex(Vector3.new(1, 0, 0), part)
		t.expect(#session.GetVertices()).toBe(2)

		session.TestAddVertex(Vector3.new(0, 0, 1), part)
		t.expect(#session.GetVertices()).toBe(3)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- GetReferencePart returns first clicked part
	--
	t.test("GetReferencePart returns first clicked part", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local partA = Instance.new("Part")
		partA.Parent = workspace
		track(partA)
		local partB = Instance.new("Part")
		partB.Parent = workspace
		track(partB)

		session.TestAddVertex(Vector3.new(0, 0, 0), partA, Vector3.yAxis)
		t.expect(session.GetReferencePart()).toBe(partA)

		-- Second vertex with different part shouldn't change referencePart
		session.TestAddVertex(Vector3.new(1, 0, 0), partB)
		t.expect(session.GetReferencePart()).toBe(partA)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- TestRemoveLastVertex removes last vertex
	--
	t.test("TestRemoveLastVertex removes last vertex", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		session.TestAddVertex(Vector3.new(0, 0, 0), part, Vector3.yAxis)
		session.TestAddVertex(Vector3.new(1, 0, 0), part)
		t.expect(#session.GetVertices()).toBe(2)

		session.TestRemoveLastVertex()
		t.expect(#session.GetVertices()).toBe(1)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- Removing all vertices clears referencePart
	--
	t.test("removing all vertices clears referencePart", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		session.TestAddVertex(Vector3.new(0, 0, 0), part, Vector3.yAxis)
		t.expect(session.GetReferencePart() ~= nil).toBe(true)

		session.TestRemoveLastVertex()
		t.expect(#session.GetVertices()).toBe(0)
		t.expect(session.GetReferencePart() == nil).toBe(true)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- CommitPolygon with >= 3 vertices creates parts and resets
	--
	t.test("CommitPolygon with 3+ vertices creates parts and resets", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		-- Use TestSetState to bypass virtualUndo (avoids ChangeHistory yield)
		session.TestSetState(
			{Vector3.new(0, 0, 0), Vector3.new(2, 0, 0), Vector3.new(0, 0, 2)},
			part,
			Vector3.yAxis
		)

		-- Count parts before commit
		local beforeCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("BasePart") and not child:IsA("Terrain") then
				beforeCount += 1
			end
		end

		session.CommitPolygon()

		-- Count parts after commit
		local afterCount = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("BasePart") and not child:IsA("Terrain") then
				afterCount += 1
			end
		end

		-- Should have created new parts
		t.expect(afterCount > beforeCount).toBe(true)

		-- Should have reset
		t.expect(#session.GetVertices()).toBe(0)
		t.expect(session.GetReferencePart() == nil).toBe(true)

		-- Clean up created parts
		for _, child in workspace:GetChildren() do
			if child:IsA("BasePart") and not child:IsA("Terrain") and child ~= part then
				track(child)
			end
		end

		session.Destroy()
		cleanupAll()
	end)

	--
	-- CommitPolygon with < 3 vertices is a no-op
	--
	t.test("CommitPolygon with fewer than 3 vertices is a no-op", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		session.TestAddVertex(Vector3.new(0, 0, 0), part, Vector3.yAxis)
		session.TestAddVertex(Vector3.new(1, 0, 0), part)

		session.CommitPolygon()

		-- Should still have 2 vertices (no-op, no reset)
		t.expect(#session.GetVertices()).toBe(2)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- ResetVertices clears everything
	--
	t.test("ResetVertices clears everything", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		local part = Instance.new("Part")
		part.Parent = workspace
		track(part)

		session.TestAddVertex(Vector3.new(0, 0, 0), part, Vector3.yAxis)
		session.TestAddVertex(Vector3.new(1, 0, 0), part)
		session.TestAddVertex(Vector3.new(0, 0, 1), part)

		session.ResetVertices()
		t.expect(#session.GetVertices()).toBe(0)
		t.expect(session.GetReferencePart() == nil).toBe(true)

		session.Destroy()
		cleanupAll()
	end)

	--
	-- Destroy completes without error
	--
	t.test("Destroy completes without error", function()
		local session = createPolygonFillSession(t.plugin, makeTestSettings())
		session.Destroy()
		t.expect(true).toBe(true)
	end)
end
