local Src = script.Parent
local Packages = Src.Parent.Packages

local Geometry = require(Packages.Geometry)

local copyPartProps = require(script.Parent.copyPartProps)
local fillTriangle = require("./fillTriangle")

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

-- Compute the depth (thickness) for a triangle fill based on edge part geometry.
-- The triangle normal is rotation-invariant, so we can compute it from any vertex ordering.
local function computeTriangleDepth(
	a, b, c,
	edgeA, edgeB,
	desiredSurfaceNormal: Vector3?,
	thicknessOverride: number?
): number
	if thicknessOverride then
		return thicknessOverride
	end

	local normal = (b - a):Cross(c - b)
	if normal.Magnitude < 1e-6 then
		return 0.05
	end
	normal = normal.Unit

	-- Determine flip direction (same logic as fillTriangle uses internally)
	local flip = 1
	local flipDetermined = false
	if desiredSurfaceNormal then
		local dot = normal:Dot(desiredSurfaceNormal)
		if math.abs(dot) > 0.1 then
			if dot > 0 then
				flip = -1
			end
			flipDetermined = true
		end
	end
	if not flipDetermined then
		if (edgeA.part.Position - a):Dot(normal) < 0 then
			flip = -1
		end
	end

	-- Calculate depth from part vertices along the normal direction
	local depth = -math.huge
	if not edgeA.inferred then
		for _, v in pairs(getPoints(edgeA.part)) do
			local d = (v - a):Dot(normal * flip)
			if d > depth then
				depth = d
			end
		end
	end
	if not edgeB.inferred then
		for _, v in pairs(getPoints(edgeB.part)) do
			local d = (v - a):Dot(normal * flip)
			if d > depth then
				depth = d
			end
		end
	end

	if edgeA.inferred and edgeB.inferred then
		depth = 0.05
	end

	return depth
end

-- Calculate the result
-- Returns the list of created parts on success, or nil on failure
local function doFill(edgeA, edgeB, extrudeDirectionModifier: number, thicknessOverride: number?, forceFactor: number, desiredSurfaceNormal: Vector3?): { BasePart }?
	local createdParts: { BasePart } = {}

	local parent;
	if edgeA.part.Parent == edgeB.part.Parent then
		parent = edgeA.part.Parent
	else
		parent = workspace
	end

	local function fill(a, b, c, normalHint)
		local depth = computeTriangleDepth(a, b, c, edgeA, edgeB, desiredSurfaceNormal, thicknessOverride)
		return fillTriangle(a, b, c, normalHint, {
			referencePart = edgeA.part,
			parent = parent,
			thickness = depth,
			forceFactor = forceFactor,
			extrudeDirectionModifier = extrudeDirectionModifier,
			desiredSurfaceNormal = desiredSurfaceNormal,
		}, createdParts)
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
			local hint = fill(edgeA.a, edgeA.b, edgeB.a)
			fill(edgeB.a, edgeB.b, edgeA.b, hint)
		else
			-- Case 2b)
			-- There is a square part to draw

			-- Figure out where the triangular parts go
			local bBottom = project(edgeB.a)
			local bTop = project(edgeB.b)
			local edgeB_adj = edgeB.a + axis*(-bBottom)
			local hint: Vector3? = nil
			if math.abs(bBottom) > 0.0001 then
				if bBottom < 0 then
					hint = fill(point, edgeB.a, edgeB_adj)
				else
					hint = fill(point, point + axis*bBottom, edgeB.a)
				end
			end
			if math.abs(bTop - edgeA.length) > 0.0001 then
				if bTop > edgeA.length then
					fill(edgeA.b, edgeB_adj + axis*edgeA.length, edgeB_adj + axis*bTop, hint)
				else
					fill(point + axis*bTop, edgeA.b, edgeB_adj + axis*bTop, hint)
				end
			end

			-- And we have the propeties of the square part, place it
			local perpDir = -normal:Cross(axis)
			local perpLen = ((edgeA.a + edgeA.direction*(edgeB.a - edgeA.a):Dot(edgeA.direction)) - edgeB.a).magnitude

			-- See if we need to flip the normal so the fill goes into the geometry.
			-- When the surface normal lies nearly in the fill plane, fall through
			-- to the referencePart position heuristic.
			local normalFlipped = false
			if desiredSurfaceNormal then
				local dot = normal:Dot(desiredSurfaceNormal)
				if math.abs(dot) > 0.1 then
					if dot > 0 then
						normal = -normal
					end
					normalFlipped = true
				end
			end
			if not normalFlipped then
				if (edgeA.part.Position - point):Dot(normal) < 0 then
					normal = -normal
				end
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
			local cf = CFrame.fromMatrix(position, normal:Cross(axis), normal, axis)

			-- Note, we can't just use a clone here because edgeA.part may be a non-square part
			-- and we can't change the className.
			local part = Instance.new('Part')
			part.Parent = parent
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			copyPartProps(edgeA.part, part)
			part.Size = size
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
