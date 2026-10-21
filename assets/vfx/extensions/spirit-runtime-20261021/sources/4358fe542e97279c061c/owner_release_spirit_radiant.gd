extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spirit-runtime-20261021/sources/2e93044a5c373736be1b/spirit_radiant.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_4358fe542e.resource(PHASE)
	return VfxPackageIO_4358fe542e.resource("res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)

const VfxPackageIO_4358fe542e = preload("res://assets/vfx/extensions/spirit-runtime-20261021/scoped_resource_io.gd")
