local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)

local copyPartProps = require(script.Parent.copyPartProps)

-- Mesh no longer needed because min part size is now 0.001 which you would
-- realistically have problems going smaller than anyways. This was historically
-- needed back when min part size was 0.05 and you frequently did need to go
-- smaller than that using a SpecialMesh.
local function setPartSizeWithMeshIfNeeded(part, meshType: Enum.MeshType, a, b, c)
	part.Size = Vector3.new(a, b, c)
end

function CFrameFromTopBack(at, top, back)
	return CFrame.fromMatrix(at, top:Cross(back), top, back)
end

local function close(a, b)
	return (a - b).magnitude < 0.001
end

local function closest(extA, dirA, extB, dirB)
	local startSep = extB - extA
	local a, b, c, d, e = dirA:Dot(dirA), dirA:Dot(dirB), dirB:Dot(dirB), dirA:Dot(startSep), dirB:Dot(startSep)
	local denom = a*c - b*b

	-- Is this a degenerate case?
	if math.abs(denom) < 0.001 then
		return nil, nil
	end

	-- Get the distances to extend by
	return -(b*e - c*d) / denom,
		-(a*e - b*d) / denom
end

local function getPoints(part)
	local geom = Geometry.getGeometry(part, part.Position)
	local points = {}
	for _, vert in pairs(geom.vertices) do
		table.insert(points, vert.position)
	end
	return points
end

-- Calculate the result
-- Returns the list of created parts on success, or nil on failure
local function doFill(edgeA, edgeB, extrudeDirectionModifier: number, thicknessOverride: number?, forceFactor: number): { BasePart }?
	local createdParts: { BasePart } = {}

	local function fill(a, b, c, normalHint)
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
		-- edge. That is the edge thatwe want to split on in order to
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

		--calculate "base" CFrame to pasition parts by
		local normal = ab:Cross(bc).unit
		local maincf = CFrameFromTopBack(a, normal, -ab.unit)

		-- Figure out if we need to flip the normal
		local flip = 1
		if (edgeA.part.Position - a):Dot(normal) < 0 then
			flip = -1
		end

		-- See what depth to use
		local depth = -math.huge
		if not edgeA.inferred then
			for _, v in pairs(getPoints(edgeA.part)) do
				local d = (v - a):Dot(normal*flip)
				if d > depth then
					depth = d
				end
			end
		end
		if not edgeB.inferred then
			for _, v in pairs(getPoints(edgeB.part)) do
				local d = (v - a):Dot(normal*flip)
				if d > depth then
					depth = d
				end
			end
		end

		if thicknessOverride then
			depth = thicknessOverride
		elseif edgeA.inferred and edgeB.inferred then
			-- No good way to determine thickness
			depth = 0.05
		end

		local parent;
		if edgeA.part.Parent == edgeB.part.Parent then
			parent = edgeA.part.Parent
		else
			parent = workspace
		end
		local part1 = Instance.new('WedgePart')
		part1.TopSurface    = Enum.SurfaceType.Smooth
		part1.BottomSurface = Enum.SurfaceType.Smooth
		copyPartProps(edgeA.part, part1)
		local part2 = part1:Clone()

		-- Apply flipping mode
		flip *= forceFactor

		-- Apply extra flipping if in extrude mode
		flip *= extrudeDirectionModifier

		if normalHint then
			if (normal*flip):Dot(normalHint) < 0 then
				flip = -flip
			end
		end

		--make parts
		if len1 > 0.001 then
			setPartSizeWithMeshIfNeeded(part1, Enum.MeshType.Wedge, depth, width, len1)
			part1.CFrame = maincf*CFrame.Angles(math.pi, 0, math.pi/2)*CFrame.new(flip*(-depth/2), width/2, len1/2)
			part1.Parent = parent
			table.insert(createdParts, part1)
		end
		if len2 > 0.001 then
			setPartSizeWithMeshIfNeeded(part2, Enum.MeshType.Wedge, depth, width, len2)
			part2.CFrame = maincf*CFrame.Angles(math.pi, math.pi, -math.pi/2)*CFrame.new(flip*(depth/2), width/2, -len1 - len2/2)
			part2.Parent = parent
			table.insert(createdParts, part2)
		end
		return normal*flip
	end

	if close(edgeA.direction, edgeB.direction) or close(edgeA.direction, -edgeB.direction) then
		-- Case 1) Rays are Parallel
		--   In this case we need to fill with a Part

		-- First make the edges face in the same direction
		if edgeA.direction:Dot(edgeB.direction) < 0 then
			edgeB.a, edgeB.b = edgeB.b, edgeB.a
			edgeB.direction = -edgeB.direction
		end

		-- The normal
		local normal = (edgeB.a - edgeA.a):Cross(edgeA.direction).unit

		-- The axis to fill on
		local point = edgeA.a
		local axis = edgeA.direction

		-- Find the "shadow" of the edges on the axis, that is, the union or
		-- intersection of the size of fill needed.
		local function project(p)
			return (p - point):Dot(axis)
		end
		local axisMin = math.max(0, project(edgeB.a))
		local axisMax = math.min(edgeA.length, project(edgeB.b))

		if axisMax <= axisMin then
			-- Case 1a)
			-- There is no square part to draw, just draw 2 triangles
			fill(edgeA.a, edgeA.b, edgeB.a)
			fill(edgeB.a, edgeB.b, edgeA.b)
		else
			-- Case 2b)
			-- There is a square part to draw

			-- Figure out where the triangular parts go
			local bBottom = project(edgeB.a)
			local bTop = project(edgeB.b)
			local edgeB_adj = edgeB.a + axis*(-bBottom)
			if math.abs(bBottom) > 0.0001 then
				if bBottom < 0 then
					fill(point, edgeB.a, edgeB_adj)
				else
					fill(point, point + axis*bBottom, edgeB.a)
				end
			end
			if math.abs(bTop - edgeA.length) > 0.0001 then
				if bTop > edgeA.length then
					fill(edgeA.b, edgeB_adj + axis*edgeA.length, edgeB_adj + axis*bTop)
				else
					fill(point + axis*bTop, edgeA.b, edgeB_adj + axis*bTop)
				end
			end

			-- And we have the propeties of the square part, place it
			local perpDir = -normal:Cross(axis)
			local perpLen = ((edgeA.a + edgeA.direction*(edgeB.a - edgeA.a):Dot(edgeA.direction)) - edgeB.a).magnitude

			-- See if we need to flip the normal, if the mass is mostly on the back-side of the normal
			if (edgeA.part.Position - point):Dot(normal) < 0 then
				normal = -normal
			end

			-- Now, find the thickness that we need for the fill. For the thickness use the
			-- depth of the first part on the normal axis.
			local maxDepth = -math.huge
			if edgeA.inferred then
				-- For inferred edges, no good way to know thickness, just pick a thin value
				if not thicknessOverride then
					maxDepth = 0.05
				end
			else
				for _, v in pairs(getPoints(edgeA.part)) do
					local depth = (v - point):Dot(normal)
					if depth > maxDepth then
						maxDepth = depth
					end
				end
			end

			-- Apply force direction
			normal *= forceFactor

			-- Apply extra flipping if in extrude mode
			normal = normal * extrudeDirectionModifier

			local thickness = thicknessOverride or maxDepth

			local position = point + axis*((axisMin + axisMax)/2) + perpDir*(perpLen/2) + normal*(thickness/2)
			local size = Vector3.new(perpLen, thickness, (axisMax - axisMin))
			local cf = CFrameFromTopBack(position, normal, axis)

			-- Note, we can't just use a clone here because edgeA.part may be a non-square part
			-- and we can't change the className.
			local part = Instance.new('Part')
			if edgeA.part.Parent == edgeB.part.Parent then
				part.Parent = edgeA.part.Parent
			else
				part.Parent = workspace
			end
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			copyPartProps(edgeA.part, part)
			setPartSizeWithMeshIfNeeded(part, Enum.MeshType.Brick, size.X, size.Y, size.Z)
			part.CFrame = cf
			table.insert(createdParts, part)
		end
	else
		-- Case 2) Rays are not parallel, we
		-- We need to fill with WedgeParts

		-- First, we need to find the triangle that the two edges are part of.
		-- To do this, we extend both rays out to their closest point of crossing.
		local extA, extB = edgeA.a, edgeB.a
		local dirA, dirB = edgeA.direction, edgeB.direction
		local endA, endB = extA + dirA*edgeA.length, extB + dirB*edgeB.length
		local lenA, lenB = closest(extA, dirA, extB, dirB)
		if not lenA or not lenB then
			warn("Failed to GapFill")
			return nil
		end

		if close(extA + dirA*lenA, extB + dirB*lenB) then
			-- The two edges are co-planar
			-- First, see if the intersection point is within both edges
			if lenA > -0.01 and lenA < edgeA.length + 0.01 and lenB > -0.01 and lenB < edgeB.length + 0.01 then
				-- Intersection is within both edges, we want to do a triangle fill
				-- The first point is the intersection point
				local pointC = extA + dirA*lenA
				local pointA, pointB;

				-- We can use the click points of both edges to see which half of the edge the user wanted to fill
				local clickA = (edgeA.click - extA):Dot(dirA)
				if clickA > lenA then
					pointA = endA
				else
					pointA = extA
				end
				local clickB = (edgeB.click - extB):Dot(dirB)
				if clickB > lenB then
					pointB = endB
				else
					pointB = extB
				end

				-- Fill in the tri
				fill(pointA, pointB, pointC)

			elseif (lenA < -0.01 or lenA > edgeA.length + 0.01) and (lenB < -0.01 or lenB > edgeB.length + 0.01) then
				-- The intersection is outside of both edges.
				-- In this case we need to use multiple triangles
				if lenA*lenB > 0 then
					fill(extA, endA, endB)
					fill(extB, endB, extA)
				else
					fill(extA, endA, endB)
					fill(extB, endB, endA)
				end
			else
				-- The intersection is on one of the lines, but not the other.
				-- First simplify the problem such that A is the edge with the intersection on it
				if lenB > -0.01 and lenB < edgeB.length + 0.01 then
					extA, extB = extB, extA
					dirA, dirB = dirB, dirA
					endA, endB = endB, endA
					lenA, lenB = lenB, lenA
					edgeA, edgeB = edgeB, edgeA
				end

				-- Still use the intersection point for point C
				local pointC = extA + dirA*lenA

				-- Now, edgeA is the one containing the intersection
				-- See which side of edge A we clicked
				local pointA;
				local clickA = (edgeA.click - extA):Dot(dirA)
				if clickA > lenA then
					pointA = endA
				else
					pointA = extA
				end

				-- And for the third point, we take the furthest away on edge B
				local pointB;
				if lenB > 0 then
					pointB = extB
				else
					pointB = endB
				end

				-- Fill it in
				fill(pointA, pointB, pointC)
			end
		else
			-- Lines are not co-planar. Create a tri which uses the first edge, and the
			-- closest point to the click point on the second edge.
			local point1, point2, point3, point4;
			local clickB = (edgeB.click - extB):Dot(dirB) / edgeB.length
			if clickB > 0.5 then
				point1 = endB
				point2 = extB
				point3 = endA
				point4 = extA
			else
				point1 = extB
				point2 = endB
				point3 = extA
				point4 = endA
			end
			if lenA*lenB > 0 then
				local normalHint = fill(point3, point4, point2)
				fill(point1, point2, point3, normalHint)
			else
				local normalHint = fill(point3, point4, point2)
				fill(point1, point2, point4, normalHint)
			end
		end
	end
	return createdParts
end

return doFill
