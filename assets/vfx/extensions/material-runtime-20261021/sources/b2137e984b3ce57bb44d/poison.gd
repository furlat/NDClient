extends "res://assets/vfx/extensions/material-runtime-20261021/sources/15fc5c01e0fc2f3f813d/liquid_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/b3d7c9c8a0da8c7ffc0d/poison-phase.tres"

static func make_component(input: Dictionary) -> Node3D:
	var parameters := input.duplicate(true)
	parameters.phase = VfxPackageIO_b2137e984b.resource(PHASE)
	return VfxPackageIO_b2137e984b.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/15fc5c01e0fc2f3f813d/liquid_occurrence.gd").make_component(parameters)

const VfxPackageIO_b2137e984b = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
