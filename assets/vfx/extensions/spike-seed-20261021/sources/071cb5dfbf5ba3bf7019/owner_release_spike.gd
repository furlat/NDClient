extends "res://assets/vfx/extensions/spike-seed-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spike-seed-20261021/sources/22a15c478bca6b5904bb/spike.tres"


static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = VfxPackageIO_071cb5dfbf.resource(PHASE)
	return VfxPackageIO_071cb5dfbf.resource("res://assets/vfx/extensions/spike-seed-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)

const VfxPackageIO_071cb5dfbf = preload("res://assets/vfx/extensions/spike-seed-20261021/scoped_resource_io.gd")
