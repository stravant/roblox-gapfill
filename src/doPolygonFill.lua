local fillTriangle = require("./fillTriangle")

-- Fan triangulation: create wedge parts filling the polygon defined by vertices.
-- Returns the list of created parts on success, or nil on failure.
local function doPolygonFill(
	vertices: { Vector3 },
	referencePart: BasePart,
	thickness: number,
	forceFactor: number,
	parent: Instance?
): { BasePart }?
	if #vertices < 3 then
		return nil
	end

	local createdParts: { BasePart } = {}
	local actualParent = parent or referencePart.Parent or workspace

	local params: fillTriangle.FillTriangleParams = {
		referencePart = referencePart,
		secondaryPart = nil,
		parent = actualParent,
		thickness = thickness,
		forceFactor = forceFactor,
		extrudeDirectionModifier = 1,
	}

	-- Compute polygon normal from first two edge vectors for consistent winding
	local normalHint: Vector3? = nil
	local edge1 = vertices[2] - vertices[1]
	local edge2 = vertices[3] - vertices[1]
	local cross = edge1:Cross(edge2)
	if cross.Magnitude > 0.0001 then
		normalHint = cross.Unit
	end

	-- Fan triangulation from vertex[1]
	for i = 2, #vertices - 1 do
		local resultNormal = fillTriangle(
			vertices[1], vertices[i], vertices[i + 1],
			normalHint,
			params,
			createdParts
		)
		-- Use the first triangle's normal as hint for the rest
		if normalHint == nil then
			normalHint = resultNormal
		end
	end

	if #createdParts == 0 then
		return nil
	end
	return createdParts
end

return doPolygonFill
