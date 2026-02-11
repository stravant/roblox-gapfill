--!strict

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local e = React.createElement

local function VertexMarker(props: {
	Position: Vector3,
	Color: Color3,
	Radius: number,
	ZIndexOffset: number,
})
	return e("SphereHandleAdornment", {
		CFrame = CFrame.new(props.Position),
		Adornee = workspace.Terrain,
		ZIndex = 0 + props.ZIndexOffset,
		Radius = props.Radius,
		Color3 = props.Color,
		Transparency = 0,
		Shading = Enum.AdornShading.XRay,
	})
end

return VertexMarker
