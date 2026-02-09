local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local doFill = require(script.Parent.doFill)

local function makeEdge(a: Vector3, b: Vector3, part: BasePart, click: Vector3?, inferred: boolean?)
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

local function makePart(position: Vector3?, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size or Vector3.new(1, 1, 1)
	part.Position = position or Vector3.zero
	part.Parent = workspace
	return part
end

-- Collect all parts that were created as children of a parent during a callback
local function collectCreatedParts(parent: Instance, fn: () -> ()): { BasePart }
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

return function(t: TestContext)
	-- Cleanup list
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
	-- Basic smoke test
	--
	t.test("returns true on success", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, 0.5),
			Vector3.new(0.5, 0.5, -0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, 0.5),
			Vector3.new(1.5, 0.5, -0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, nil, 1)
			t.expect(result).toBe(true)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do track(p) end
		cleanupAll()
	end)

	--
	-- Case 1: Parallel edges - overlapping projection (rectangular fill)
	--
	t.test("parallel overlapping edges create a Part", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		-- Two parallel edges along Z, separated along X
		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, nil, 1)
		end)

		-- Should create exactly 1 Part (rectangular fill, full overlap)
		local partCount = 0
		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			else
				partCount += 1
			end
		end
		t.expect(partCount).toBe(1)
		t.expect(wedgeCount).toBe(0)
		cleanupAll()
	end)

	--
	-- Case 1a: Parallel edges - no overlap (two triangles)
	--
	t.test("parallel non-overlapping edges create WedgeParts", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 2))
		track(partA)
		track(partB)

		-- Parallel along Z but offset so no overlap
		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, 1.5),
			Vector3.new(1.5, 0.5, 2.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, nil, 1)
		end)

		-- Should create WedgeParts (triangular fills)
		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Case 1: Parallel edges partially overlapping (rect + wedges)
	--
	t.test("parallel partially overlapping edges create Part and WedgeParts", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0.5))
		track(partA)
		track(partB)

		-- Parallel along Z, partially overlapping
		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, 0),
			Vector3.new(1.5, 0.5, 1.0),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, nil, 1)
		end)

		local partCount = 0
		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			else
				partCount += 1
			end
		end
		-- Rect for overlapping region + wedges for the ends
		t.expect(partCount).toBe(1)
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Case 2: Non-parallel coplanar edges intersecting within both
	--
	t.test("non-parallel coplanar edges with intersection within both create WedgeParts", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(0, 0, 0))
		track(partA)
		track(partB)

		-- Two edges forming a V shape, meeting at origin
		local edgeA = makeEdge(
			Vector3.new(-1, 0, 0),
			Vector3.new(1, 0, 0),
			partA,
			Vector3.new(0.5, 0, 0) -- click on right half
		)
		local edgeB = makeEdge(
			Vector3.new(0, 0, -1),
			Vector3.new(0, 0, 1),
			partB,
			Vector3.new(0, 0, 0.5) -- click on positive Z half
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, 0.1, 1)
			t.expect(result).toBe(true)
		end)

		-- Should create wedge parts for the triangle
		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Case 2: Non-parallel coplanar edges, intersection outside both
	--
	t.test("non-parallel coplanar edges with intersection outside both", function()
		local partA = makePart(Vector3.new(1, 0, 0))
		local partB = makePart(Vector3.new(0, 0, 1))
		track(partA)
		track(partB)

		-- Two edges that diverge, intersection behind both start points
		local edgeA = makeEdge(
			Vector3.new(1, 0, 0),
			Vector3.new(2, 0, 0),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(0, 0, 1),
			Vector3.new(0, 0, 2),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, 0.1, 1)
			t.expect(result).toBe(true)
		end)

		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		-- Should produce multiple wedge parts (two triangles)
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Case 2: Non-coplanar edges
	--
	t.test("non-coplanar edges create WedgeParts", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 1, 0))
		track(partA)
		track(partB)

		-- Edges in different planes with different directions (not parallel)
		local edgeA = makeEdge(
			Vector3.new(0, 0, -0.5),
			Vector3.new(0, 0, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(2, 1, 0),
			Vector3.new(3, 1, 0),
			partB,
			Vector3.new(2.5, 1, 0) -- click in middle
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, 0.1, 1)
			t.expect(result).toBe(true)
		end)

		local wedgeCount = 0
		for _, p in created do
			track(p)
			if p:IsA("WedgePart") then
				wedgeCount += 1
			end
		end
		t.expect(wedgeCount > 0).toBe(true)
		cleanupAll()
	end)

	--
	-- Thickness override
	--
	t.test("thickness override is respected", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local thicknessOverride = 0.25

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, thicknessOverride, 1)
		end)

		for _, p in created do
			track(p)
			-- For the rectangular fill, one dimension of size should match the override
			-- Account for mesh scaling
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local effectiveSize
			if mesh then
				effectiveSize = p.Size * mesh.Scale
			else
				effectiveSize = p.Size
			end
			-- At least one axis should be close to the thickness override
			local minSize = math.min(effectiveSize.X, effectiveSize.Y, effectiveSize.Z)
			-- The thickness should be within a small tolerance of the override
			t.expect(math.abs(minSize - thicknessOverride) < 0.01).toBe(true)
		end
		cleanupAll()
	end)

	--
	-- Inferred edges use thin default
	--
	t.test("inferred edges without override use thin default", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA,
			nil,
			true -- inferred
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB,
			nil,
			true -- inferred
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, nil, 1)
		end)

		for _, p in created do
			track(p)
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local effectiveSize
			if mesh then
				effectiveSize = p.Size * mesh.Scale
			else
				effectiveSize = p.Size
			end
			local minSize = math.min(effectiveSize.X, effectiveSize.Y, effectiveSize.Z)
			-- Default thin is 0.05
			t.expect(math.abs(minSize - 0.05) < 0.01).toBe(true)
		end
		cleanupAll()
	end)

	--
	-- Parts parent to common ancestor
	--
	t.test("created parts parent to common parent of edge parts", function()
		local folder = Instance.new("Folder")
		folder.Parent = workspace
		track(folder)

		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		partA.Parent = folder
		partB.Parent = folder
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local created = collectCreatedParts(folder, function()
			doFill(edgeA, edgeB, 1, 0.1, 1)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do
			track(p)
			t.expect(p.Parent).toBe(folder)
		end
		cleanupAll()
	end)

	--
	-- Parts with different parents go to workspace
	--
	t.test("created parts parent to workspace when edge parts have different parents", function()
		local folderA = Instance.new("Folder")
		folderA.Parent = workspace
		track(folderA)
		local folderB = Instance.new("Folder")
		folderB.Parent = workspace
		track(folderB)

		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		partA.Parent = folderA
		partB.Parent = folderB
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, 0.1, 1)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do
			track(p)
			t.expect(p.Parent).toBe(workspace)
		end
		cleanupAll()
	end)

	--
	-- Properties are copied from source part
	--
	t.test("copies properties from source part", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		partA.Color = Color3.new(1, 0, 0)
		partA.Material = Enum.Material.Neon
		partA.Transparency = 0.5
		partA.Reflectance = 0.3
		track(partA)
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, 0.1, 1)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do
			track(p)
			t.expect(p.Color).toEqual(Color3.new(1, 0, 0))
			t.expect(p.Material).toBe(Enum.Material.Neon)
			t.expect(math.abs(p.Transparency - 0.5) < 0.01).toBe(true)
			t.expect(math.abs(p.Reflectance - 0.3) < 0.01).toBe(true)
		end
		cleanupAll()
	end)

	--
	-- Force factor flips direction
	--
	t.test("force factor -1 produces different orientation than 1", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		local function makeEdges()
			local eA = makeEdge(
				Vector3.new(0.5, 0.5, -0.5),
				Vector3.new(0.5, 0.5, 0.5),
				partA
			)
			local eB = makeEdge(
				Vector3.new(1.5, 0.5, -0.5),
				Vector3.new(1.5, 0.5, 0.5),
				partB
			)
			return eA, eB
		end

		local edgeA1, edgeB1 = makeEdges()
		local created1 = collectCreatedParts(workspace, function()
			doFill(edgeA1, edgeB1, 1, 0.1, 1)
		end)
		local cframes1 = {}
		for _, p in created1 do
			track(p)
			table.insert(cframes1, p.CFrame)
		end

		local edgeA2, edgeB2 = makeEdges()
		local created2 = collectCreatedParts(workspace, function()
			doFill(edgeA2, edgeB2, 1, 0.1, -1)
		end)
		local cframes2 = {}
		for _, p in created2 do
			track(p)
			table.insert(cframes2, p.CFrame)
		end

		-- The two fills should produce different CFrames
		t.expect(#cframes1).toBe(#cframes2)
		local anyDifferent = false
		for i = 1, #cframes1 do
			if (cframes1[i].Position - cframes2[i].Position).Magnitude > 0.001 then
				anyDifferent = true
			end
		end
		t.expect(anyDifferent).toBe(true)
		cleanupAll()
	end)

	--
	-- Opposite-facing parallel edges are normalized
	--
	t.test("parallel edges facing opposite directions still fill correctly", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		-- edgeB faces opposite direction to edgeA
		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, 0.5),
			Vector3.new(1.5, 0.5, -0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, 0.1, 1)
			t.expect(result).toBe(true)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do track(p) end
		cleanupAll()
	end)

	--
	-- Extrude direction modifier
	--
	t.test("extrude direction modifier -1 flips orientation", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		track(partA)

		-- Same part for both edges (extrude mode)
		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partA
		)

		local created1 = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, 0.1, 1)
		end)
		local cframes1 = {}
		for _, p in created1 do
			track(p)
			table.insert(cframes1, p.CFrame)
		end

		-- Reset edges (doFill may mutate them for parallel case)
		edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partA
		)

		local created2 = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, -1, 0.1, 1)
		end)
		local cframes2 = {}
		for _, p in created2 do
			track(p)
			table.insert(cframes2, p.CFrame)
		end

		-- Should produce different orientations
		t.expect(#cframes1).toBe(#cframes2)
		local anyDifferent = false
		for i = 1, #cframes1 do
			if (cframes1[i].Position - cframes2[i].Position).Magnitude > 0.001 then
				anyDifferent = true
			end
		end
		t.expect(anyDifferent).toBe(true)
		cleanupAll()
	end)

	--
	-- Very small edges still work (mesh scaling)
	--
	t.test("very small fill uses SpecialMesh for sub-0.05 dimensions", function()
		local partA = makePart(Vector3.new(0, 0, 0), Vector3.new(0.05, 0.05, 0.05))
		local partB = makePart(Vector3.new(0.1, 0, 0), Vector3.new(0.05, 0.05, 0.05))
		track(partA)
		track(partB)

		-- Use a very small thickness override to force sub-0.05 dimension
		local edgeA = makeEdge(
			Vector3.new(0.025, 0.025, -0.025),
			Vector3.new(0.025, 0.025, 0.025),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(0.075, 0.025, -0.025),
			Vector3.new(0.075, 0.025, 0.025),
			partB
		)

		-- Force a thickness of 0.01 which is below the 0.05 minimum

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, 0.01, 1)
		end)

		t.expect(#created > 0).toBe(true)
		-- With 0.01 thickness override, parts need SpecialMesh for the sub-0.05 dimension
		local hasMesh = false
		for _, p in created do
			track(p)
			if p:FindFirstChildOfClass("SpecialMesh") then
				hasMesh = true
			end
		end
		t.expect(hasMesh).toBe(true)
		cleanupAll()
	end)

	--
	-- 90-degree angle edges (common use case)
	--
	t.test("90-degree angle edges fill correctly", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(1, 0, 0))
		track(partA)
		track(partB)

		-- Two edges at right angles meeting at a corner
		local edgeA = makeEdge(
			Vector3.new(0, 0, 0),
			Vector3.new(1, 0, 0),
			partA,
			Vector3.new(0.5, 0, 0)
		)
		local edgeB = makeEdge(
			Vector3.new(0, 0, 0),
			Vector3.new(0, 0, 1),
			partB,
			Vector3.new(0, 0, 0.5)
		)

		local created = collectCreatedParts(workspace, function()
			local result = doFill(edgeA, edgeB, 1, 0.1, 1)
			t.expect(result).toBe(true)
		end)

		t.expect(#created > 0).toBe(true)
		for _, p in created do track(p) end
		cleanupAll()
	end)

	--
	-- Surfaces are smooth
	--
	t.test("created parts have smooth surfaces", function()
		local partA = makePart(Vector3.new(0, 0, 0))
		local partB = makePart(Vector3.new(2, 0, 0))
		track(partA)
		track(partB)

		local edgeA = makeEdge(
			Vector3.new(0.5, 0.5, -0.5),
			Vector3.new(0.5, 0.5, 0.5),
			partA
		)
		local edgeB = makeEdge(
			Vector3.new(1.5, 0.5, -0.5),
			Vector3.new(1.5, 0.5, 0.5),
			partB
		)

		local created = collectCreatedParts(workspace, function()
			doFill(edgeA, edgeB, 1, 0.1, 1)
		end)

		for _, p in created do
			track(p)
			t.expect(p.TopSurface).toBe(Enum.SurfaceType.Smooth)
			t.expect(p.BottomSurface).toBe(Enum.SurfaceType.Smooth)
		end
		cleanupAll()
	end)
end
