extends RefCounted
## A material-bearing plane: useful for glyphs, masks and flat effect layers.
## Geometry/material selection is input data; camera and timing belong to recipes.

const ShaderMaterialBuilder = preload("res://assets/vfx/sources/601eb8db9c55b6ad084e/shader_material.gd")


static func make_component(parameters: Dictionary) -> MeshInstance3D:
	var dimensions: Array = parameters.get("size", [2.0, 2.0])
	if dimensions.size() != 2 or dimensions[0] <= 0 or dimensions[1] <= 0:
		push_error("Material plane requires two positive dimensions.")
		return null
	var material := ShaderMaterialBuilder.build(parameters.get("material", {}))
	if material == null:
		return null
	var mesh := QuadMesh.new()
	mesh.size = Vector2(dimensions[0], dimensions[1])
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance
