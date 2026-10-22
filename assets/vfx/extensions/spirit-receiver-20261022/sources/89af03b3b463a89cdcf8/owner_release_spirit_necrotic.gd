extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spirit-receiver-20261022/sources/e9c552183a421cae7c90/spirit_necrotic.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_89af03b3b4.resource(PHASE)
	return VfxPackageIO_89af03b3b4.resource("res://assets/vfx/extensions/spirit-receiver-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)

const VfxPackageIO_89af03b3b4 = preload("res://assets/vfx/extensions/spirit-receiver-20261022/scoped_resource_io.gd")
