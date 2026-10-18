extends "res://assets/vfx/sources/617c482d75186521eb0f/ice_storm_irregular_composition.gd"


static func make_component(input: Dictionary) -> Node3D:
	var node: Node3D = VfxPackageIO_0e65a0a571.resource("res://assets/vfx/sources/0e65a0a5710570336194/ice_storm_solid_composition.gd").new()
	node.selections = input.entries.duplicate(true)
	node.opacity_control = input.get("opacity_control", false)
	return node


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result.fracture.original_exterior_uv_and_texture = false
	result.fracture.solid_geometry = "closed convex boundary of actual donor positions; source vertex UV seams and textures retained, outward geometric normals"
	return result

const VfxPackageIO_0e65a0a571 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
