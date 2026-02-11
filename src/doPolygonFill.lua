local fillTriangle = require("./fillTriangle")

-- Fan triangulation: create wedge parts filling the polygon defined by vertices.
-- Returns the list of created parts on success, or nil on failure.
local function doPolygonFill(
	vertices: { Vector3 },
	referencePart: BasePart,
	surfaceNormal: Vector3?,
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

	-- Use the negated surface normal as the direction hint: the hit normal
	-- points outward from the clicked surface, so negate it to make the fill
	-- go into the geometry (flush with the adjacent surface).
	local normalHint: Vector3? = if surfaceNormal then -surfaceNormal else nil

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
