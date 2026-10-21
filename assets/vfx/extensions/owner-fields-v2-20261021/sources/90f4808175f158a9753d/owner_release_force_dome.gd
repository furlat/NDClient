extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/b9f0c56911c9ba3b6812/force_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/f0f6f2d4f36bce8317e4/force_dome.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_90f4808175.resource(PHASE)
	return VfxPackageIO_90f4808175.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/b9f0c56911c9ba3b6812/force_occurrence.gd").make_component(actual)

const VfxPackageIO_90f4808175 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
