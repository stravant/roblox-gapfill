--!strict

local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local e = React.createElement

local function WireframeEdge(props: {
	From: Vector3,
	To: Vector3,
	Color: Color3,
	Radius: number,
	ZIndexOffset: number,
})
	local diff = props.To - props.From
	local length = diff.Magnitude
	if length < 0.001 then
		return nil
	end

	local midpoint = (props.From + props.To) / 2
	local cf = CFrame.new(midpoint, props.To) * CFrame.Angles(0, 0, math.pi / 2)

	return e("CylinderHandleAdornment", {
		CFrame = cf,
		Adornee = workspace.Terrain,
		ZIndex = 0 + props.ZIndexOffset,
		Height = length,
		Radius = props.Radius,
		Color3 = props.Color,
		Transparency = 0,
		Shading = Enum.AdornShading.XRay,
	})
end

return WireframeEdge
