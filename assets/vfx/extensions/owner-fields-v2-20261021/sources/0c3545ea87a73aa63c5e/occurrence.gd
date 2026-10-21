extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
const Construction = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/1f8285c1d575c82f5a3e/observed_solid_wall_construction.gd")

static func make_component(input: Dictionary) -> Node3D:
	if not input.get("phase") is Resource:
		return null
	var clip := Construction.clip_for(input.phase, input)
	if clip.is_empty():
		return null
	var node: Node3D = VfxPackageIO_0c3545ea87.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/0c3545ea87a73aa63c5e/occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node

func set_zone_geometry(value: Dictionary) -> void:
	forward("set_zone_geometry", value)

const VfxPackageIO_0c3545ea87 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
