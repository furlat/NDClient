extends "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/owner-fields-v2-20261021/sources/1b7f19780b26c6798b82/sleet.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_466f2cf191.resource(PHASE)
	return VfxPackageIO_466f2cf191.resource("res://assets/vfx/extensions/owner-fields-v2-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)

const VfxPackageIO_466f2cf191 = preload("res://assets/vfx/extensions/owner-fields-v2-20261021/scoped_resource_io.gd")
