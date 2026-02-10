--!strict

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local e = React.createElement

export type EdgeData = {
	a: Vector3,
	b: Vector3,
	length: number,
	cameraDepth: number,
}

local function EdgeArrow(props: {
	Edge: EdgeData,
	Color: Color3,
	ZIndexOffset: number,
})
	local edge = props.Edge
	local color = props.Color
	local zmod = props.ZIndexOffset

	local scale = edge.cameraDepth / 150

	local segmentCFrame = CFrame.new(edge.a, edge.b) * CFrame.new(0, 0, -edge.length / 2)
	local tipLength = math.min(0.35 * edge.length, scale * 7.2)
	local tipRadius = tipLength / 3
	local shaftRadius = tipRadius / 3

	local shaftCFrame = segmentCFrame * CFrame.new(0, 0, tipLength / 2) * CFrame.Angles(0, 0, math.pi / 2)
	local shaftHeight = edge.length - tipLength

	local headCFrame = segmentCFrame * CFrame.new(0, 0, -(edge.length / 2 - tipLength)) * CFrame.Angles(0, 0, math.pi / 2)

	return e("Folder", {}, {
		Shaft = e("CylinderHandleAdornment", {
			CFrame = shaftCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 0 + zmod,
			Height = shaftHeight,
			Radius = shaftRadius,
			Color3 = color,
			Transparency = 0,
			Shading = Enum.AdornShading.XRay,
		}),
		Head = e("ConeHandleAdornment", {
			CFrame = headCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 1 + zmod,
			Height = tipLength,
			Radius = tipRadius,
			Color3 = color,
			Transparency = 0,
			Shading = Enum.AdornShading.XRay,
		}),
	})
end

return EdgeArrow
