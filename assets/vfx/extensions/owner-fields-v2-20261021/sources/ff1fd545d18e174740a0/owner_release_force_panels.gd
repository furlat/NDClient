extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/b9f0c56911c9ba3b6812/force_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/9aa7b3266c8d9dd2a5cc/force_panels.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_ff1fd545d1.resource(PHASE)
	return VfxPackageIO_ff1fd545d1.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/b9f0c56911c9ba3b6812/force_occurrence.gd").make_component(actual)

const VfxPackageIO_ff1fd545d1 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
