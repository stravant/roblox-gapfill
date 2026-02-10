--!strict

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local e = React.createElement

export type EdgeData = {
	a: Vector3,
	b: Vector3,
	length: number,
	vertexMargin: number?,
}

local function EdgeArrow(props: {
	Edge: EdgeData,
	Color: Color3,
	ZIndexOffset: number,
})
	local face = props.Edge
	local color = props.Color
	local zmod = props.ZIndexOffset

	local scale = math.max(face.vertexMargin or 0, 0.15) / 8
	if scale > 0.2 then
		scale = 0.2
	end

	local segmentCFrame = CFrame.new(face.a, face.b) * CFrame.new(0, 0, -face.length / 2)
	local tipLength = math.min(0.3 * face.length, scale * 15)
	local tipRadius = 0.5 * tipLength
	local shaftRadius = 0.5 * 0.5 * math.min(0.3 * face.length, scale * 7)

	local shaftCFrame = segmentCFrame * CFrame.new(0, 0, tipLength / 2) * CFrame.Angles(0, 0, math.pi / 2)
	local shaftHeight = face.length - tipLength

	local headCFrame = segmentCFrame * CFrame.new(0, 0, -(face.length / 2 - tipLength)) * CFrame.Angles(0, 0, math.pi / 2)

	return e("Folder", {}, {
		Shaft = e("CylinderHandleAdornment", {
			CFrame = shaftCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 0 + zmod,
			Height = shaftHeight,
			Radius = shaftRadius,
			Color3 = color,
			Transparency = 0,
			AlwaysOnTop = false,
		}),
		ShaftOnTop = e("CylinderHandleAdornment", {
			CFrame = shaftCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 0 + zmod,
			Height = shaftHeight,
			Radius = shaftRadius,
			Color3 = color,
			Transparency = 0.7,
			AlwaysOnTop = true,
		}),
		Head = e("ConeHandleAdornment", {
			CFrame = headCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 1 + zmod,
			Height = tipLength,
			Radius = tipRadius,
			Color3 = color,
			Transparency = 0,
			AlwaysOnTop = false,
		}),
		HeadOnTop = e("ConeHandleAdornment", {
			CFrame = headCFrame,
			Adornee = workspace.Terrain,
			ZIndex = 1 + zmod,
			Height = tipLength,
			Radius = tipRadius,
			Color3 = color,
			Transparency = 0.7,
			AlwaysOnTop = true,
		}),
	})
end

return EdgeArrow
