--!strict

local copyPartProps = require("./copyPartProps")

local function CFrameFromTopBack(at, top, back)
	return CFrame.fromMatrix(at, top:Cross(back), top, back)
end

export type FillTriangleParams = {
	referencePart: BasePart,
	secondaryPart: BasePart?,
	parent: Instance,
	thickness: number,
	forceFactor: number,
	extrudeDirectionModifier: number,
}

-- Fill a single triangle with wedge parts.
-- Returns the normal used and appends created parts to createdParts.
local function fillTriangle(
	a: Vector3, b: Vector3, c: Vector3,
	normalHint: Vector3?,
	params: FillTriangleParams,
	createdParts: { BasePart }
): Vector3
	--[[       edg1
		A ------|------>B  --.
		'\      |      /      \
		  \part1|part2/       |
		   \   cut   /       / Direction edges point in:
	   edg3 \       / edg2  /        (clockwise)
		     \     /      |/
		      \<- /       ¯¯
		       \ /
		        C
	--]]
	local ab, bc, ca = b-a, c-b, a-c
	local abm, bcm, cam = ab.magnitude, bc.magnitude, ca.magnitude
	local e1, e2, e3 = ca:Dot(ab)/(abm*abm), ab:Dot(bc)/(bcm*bcm), bc:Dot(ca)/(cam*cam)
	local edg1 = math.abs(0.5 + e1)
	local edg2 = math.abs(0.5 + e2)
	local edg3 = math.abs(0.5 + e3)
	-- Idea: Find the edge onto which the vertex opposite that
	-- edge has the projection closest to 1/2 of the way along that
	-- edge. That is the edge that we want to split on in order to
	-- avoid ending up with small "sliver" triangles with one very
	-- small dimension relative to the other one.
	if math.abs(e1) > 0.0001 and math.abs(e2) > 0.0001 and math.abs(e3) > 0.0001 then
		if edg1 < edg2 then
			if edg1 < edg3 then
				-- min is edg1: less than both
				-- nothing to change
			else
				-- min is edg3: edg3 < edg1 < edg2
				-- "rotate" verts twice counterclockwise
				a, b, c = c, a, b
				ab, bc, ca = ca, ab, bc
				abm = cam
			end
		else
			if edg2 < edg3 then
				-- min is edg2: less than both
				-- "rotate" verts once counterclockwise
				a, b, c = b, c, a
				ab, bc, ca = bc, ca, ab
				abm = bcm
			else
				-- min is edg3: edg3 < edg2 < edg1
				-- "rotate" verts twice counterclockwise
				a, b, c = c, a, b
				ab, bc, ca = ca, ab, bc
				abm = cam
			end
		end
	else
		if math.abs(e1) <= 0.0001 then
			-- nothing to do
		elseif math.abs(e2) <= 0.0001 then
			-- use e2
			a, b, c = b, c, a
			ab, bc, ca = bc, ca, ab
			abm = bcm
		else
			-- use e3
			a, b, c = c, a, b
			ab, bc, ca = ca, ab, bc
			abm = cam
		end
	end

	--calculate lengths
	local len1 = -ca:Dot(ab)/abm
	local len2 = abm - len1
	local width = (ca + ab.unit*len1).magnitude

	--calculate "base" CFrame to position parts by
	local normal = ab:Cross(bc).unit
	local maincf = CFrameFromTopBack(a, normal, -ab.unit)

	-- Figure out if we need to flip the normal
	local flip = 1
	if (params.referencePart.Position - a):Dot(normal) < 0 then
		flip = -1
	end

	-- See what depth to use
	local depth = params.thickness

	local part1 = Instance.new('Part')
	part1.Shape = Enum.PartType.Wedge
	part1.TopSurface    = Enum.SurfaceType.Smooth
	part1.BottomSurface = Enum.SurfaceType.Smooth
	copyPartProps(params.referencePart, part1)
	local part2 = part1:Clone()

	-- Apply flipping mode
	flip *= params.forceFactor

	-- Apply extra flipping if in extrude mode
	flip *= params.extrudeDirectionModifier

	if normalHint then
		if (normal*flip):Dot(normalHint) < 0 then
			flip = -flip
		end
	end

	--make parts
	if len1 > 0.001 then
		part1.Size = Vector3.new(depth, width, len1)
		part1.CFrame = maincf*CFrame.Angles(math.pi, 0, math.pi/2)*CFrame.new(flip*(-depth/2), width/2, len1/2)
		part1.Parent = params.parent
		table.insert(createdParts, part1)
	end
	if len2 > 0.001 then
		part2.Size = Vector3.new(depth, width, len2)
		part2.CFrame = maincf*CFrame.Angles(math.pi, math.pi, -math.pi/2)*CFrame.new(flip*(depth/2), width/2, -len1 - len2/2)
		part2.Parent = params.parent
		table.insert(createdParts, part2)
	end
	return normal*flip
end

return fillTriangle
