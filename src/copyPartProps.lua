return function(fromPart: BasePart, toPart: BasePart)
	toPart.Anchored     = fromPart.Anchored
	toPart.Massless     = fromPart.Massless
	toPart.RootPriority = fromPart.RootPriority
	toPart.CustomPhysicalProperties = fromPart.CustomPhysicalProperties
	--
	toPart.CanCollide   = fromPart.CanCollide
	toPart.CanTouch     = fromPart.CanTouch
	toPart.CanQuery     = fromPart.CanQuery
	toPart.CollisionGroupId = fromPart.CollisionGroupId
	toPart.CollisionGroup = fromPart.CollisionGroup
	--
	toPart.Color        = fromPart.Color
	toPart.CastShadow   = fromPart.CastShadow
	toPart.Material     = fromPart.Material
	toPart.Reflectance  = fromPart.Reflectance
	toPart.Transparency = fromPart.Transparency
end