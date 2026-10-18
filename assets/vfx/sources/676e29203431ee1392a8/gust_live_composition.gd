extends "res://assets/vfx/sources/0738ff2d24aa41b1b963/native_review_composition.gd"
## Family-local live packet seam for the shared sampler's same-age fast path.

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = VfxPackageIO_676e292034.resource("res://assets/vfx/sources/676e29203431ee1392a8/gust_live_composition.gd").new()
	instance.definition = input.duplicate(true)
	return instance


func set_live_endpoints(value: Array) -> void:
	super.set_live_endpoints(value)
	if composition == null:
		return
	for component in composition.components.values():
		component.set_live_endpoints(value)
	if value.size() >= 3:
		# Preserve source-space masks when the host subsequently applies this
		# explicit caster-ground translation at the same source age.
		var placement: Transform3D = global_transform
		placement.origin = value[0].point
		for material in source_materials:
			material.set_shader_parameter("factory_world_to_source", Projection(placement.affine_inverse()))

const VfxPackageIO_676e292034 = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
