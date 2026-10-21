extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"
const Construction = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/ccb679e72e00c39f61de/observed_forcecage_construction.gd")

static func make_component(input: Dictionary) -> Node3D:
	if not input.get("phase") is Resource:
		return null
	var clip := Construction.clip_for(input.phase, input)
	if clip.is_empty():
		return null
	var node: Node3D = VfxPackageIO_99f1d493f6.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd").new()
	node.parameters = input.duplicate(true)
	node.parameters.clip = clip
	return node

func set_zone_geometry(value: Dictionary) -> void:
	forward("set_zone_geometry", value)

const VfxPackageIO_99f1d493f6 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
