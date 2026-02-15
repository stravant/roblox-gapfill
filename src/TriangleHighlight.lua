--!strict

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local e = React.createElement

-- Renders a right-angle triangle using two ConeHandleAdornments.
-- B must be the vertex at the right angle.
-- (Technique from ResizeAlign's FaceHighlight)
local function RightAngleTriangleAdornment(props: {
	A: Vector3,
	B: Vector3,
	C: Vector3,
	Transparency: number,
	ZIndexOffset: number,
	Color: Color3,
})
	local ab = props.B - props.A
	local bc = props.C - props.B
	local normal = ab:Cross(bc)
	if normal.Magnitude < 0.001 then
		return nil
	end
	normal = normal.Unit
	local mid = (props.A + props.C) * 0.5
	local abmid = props.A + 0.5 * ab
	local bcmid = props.B + 0.5 * bc

	local children: { [string]: any } = {}
	if ab.Magnitude > 0.001 then
		children.A = e("ConeHandleAdornment", {
			Adornee = workspace.Terrain,
			Height = (mid - abmid).Magnitude,
			Radius = ab.Magnitude / 2,
			CFrame = CFrame.fromMatrix(abmid, ab.Unit, Vector3.zero, ab.Unit:Cross(normal).Unit),
			ZIndex = 1 + props.ZIndexOffset,
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		})
	end
	if bc.Magnitude > 0.001 then
		children.B = e("ConeHandleAdornment", {
			Adornee = workspace.Terrain,
			Height = (mid - bcmid).Magnitude,
			Radius = bc.Magnitude / 2,
			CFrame = CFrame.fromMatrix(bcmid, ab.Unit:Cross(normal).Unit, Vector3.zero, ab.Unit),
			ZIndex = 1 + props.ZIndexOffset,
			AlwaysOnTop = true,
			Transparency = props.Transparency,
			Color3 = props.Color,
		})
	end

	return e(React.Fragment, nil, children)
end

-- Renders a filled triangle highlight using only HandleAdornments.
-- Decomposes the triangle into two right-angle triangles by dropping
-- a perpendicular from the vertex opposite the longest edge.
local function TriangleHighlight(props: {
	A: Vector3,
	B: Vector3,
	C: Vector3,
	Color: Color3,
	Transparency: number,
	ZIndexOffset: number,
})
	local a, b, c = props.A, props.B, props.C
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)

	-- Rearrange so that the longest edge is bc (opposite vertex a).
	-- This guarantees the perpendicular foot lands between b and c.
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > abd and acd > bcd then
		a, b = b, a
	end

	ab, ac, bc = b - a, c - a, c - b

	if ac:Cross(ab).Magnitude < 0.001 then
		return nil -- degenerate triangle
	end

	-- Drop perpendicular from a onto line bc to get foot point d
	local bcUnit = bc.Unit
	local t = (a - b):Dot(bcUnit)
	local d = b + bcUnit * t

	-- Two right-angle triangles sharing the perpendicular leg (d→a),
	-- with right angle at d
	return e(React.Fragment, nil, {
		Tri1 = e(RightAngleTriangleAdornment, {
			A = b,
			B = d,
			C = a,
			Transparency = props.Transparency,
			ZIndexOffset = props.ZIndexOffset,
			Color = props.Color,
		}),
		Tri2 = e(RightAngleTriangleAdornment, {
			A = a,
			B = d,
			C = c,
			Transparency = props.Transparency,
			ZIndexOffset = props.ZIndexOffset,
			Color = props.Color,
		}),
	})
end

return TriangleHighlight
