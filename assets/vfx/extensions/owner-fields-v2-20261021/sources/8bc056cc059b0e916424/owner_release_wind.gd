extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/f2699aff8bd985672766/wind.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_8bc056cc05.resource(PHASE)
	return VfxPackageIO_8bc056cc05.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)

const VfxPackageIO_8bc056cc05 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
