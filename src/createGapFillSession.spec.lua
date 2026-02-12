local TestTypes = require(script.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local createGapFillSession = require(script.Parent.createGapFillSession)
local TestHelpers = require(script.Parent.TestHelpers)

local makeTestSettings = TestHelpers.makeTestSettings
local makeEdge = TestHelpers.makeEdge

return function(t: TestContext)
	--
	-- Starts in EdgeA state
	--
	t.test("starts in EdgeA state", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())
		t.expect(session.GetEdgeState()).toBe("EdgeA")
		session.Destroy()
	end)

	--
	-- TestSelectEdge transitions to EdgeB
	--
	t.test("TestSelectEdge transitions to EdgeB", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local edge = makeEdge(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), part)

		session.TestSelectEdge(edge, Vector3.yAxis)
		t.expect(session.GetEdgeState()).toBe("EdgeB")

		session.Destroy()
		part:Destroy()
	end)

	--
	-- GetSelectedEdge returns edge data in EdgeB state
	--
	t.test("GetSelectedEdge returns edge data in EdgeB state", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local edge = makeEdge(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), part)

		session.TestSelectEdge(edge, Vector3.yAxis)
		local selected = session.GetSelectedEdge()
		t.expect(selected ~= nil).toBe(true)
		t.expect(selected.a).toEqual(Vector3.new(0, 0, 0))
		t.expect(selected.b).toEqual(Vector3.new(1, 0, 0))

		session.Destroy()
		part:Destroy()
	end)

	--
	-- TestResetEdge goes back to EdgeA, clears selected edge
	--
	t.test("TestResetEdge goes back to EdgeA", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())

		local part = Instance.new("Part")
		part.Parent = workspace
		local edge = makeEdge(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), part)

		session.TestSelectEdge(edge, Vector3.yAxis)
		t.expect(session.GetEdgeState()).toBe("EdgeB")

		session.TestResetEdge()
		t.expect(session.GetEdgeState()).toBe("EdgeA")
		t.expect(session.GetSelectedEdge() == nil).toBe(true)

		session.Destroy()
		part:Destroy()
	end)

	--
	-- ChangeSignal fires on transitions
	--
	t.test("ChangeSignal fires on transitions", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())

		local fireCount = 0
		session.ChangeSignal:Connect(function()
			fireCount += 1
		end)

		local part = Instance.new("Part")
		part.Parent = workspace
		local edge = makeEdge(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), part)

		session.TestSelectEdge(edge, Vector3.yAxis)
		t.expect(fireCount).toBe(1)

		session.TestResetEdge()
		t.expect(fireCount).toBe(2)

		session.Destroy()
		part:Destroy()
	end)

	--
	-- Destroy completes without error
	--
	t.test("Destroy completes without error", function()
		local session = createGapFillSession(t.plugin, makeTestSettings())
		session.Destroy()
		-- If we got here, no error was thrown
		t.expect(true).toBe(true)
	end)
end
