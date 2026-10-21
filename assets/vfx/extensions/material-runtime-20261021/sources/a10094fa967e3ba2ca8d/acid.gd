extends "res://assets/vfx/extensions/material-runtime-20261021/sources/15fc5c01e0fc2f3f813d/liquid_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/66d0f866197b5da47066/acid-phase.tres"

static func make_component(input: Dictionary) -> Node3D:
	var parameters := input.duplicate(true)
	parameters.phase = VfxPackageIO_a10094fa96.resource(PHASE)
	return VfxPackageIO_a10094fa96.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/15fc5c01e0fc2f3f813d/liquid_occurrence.gd").make_component(parameters)

const VfxPackageIO_a10094fa96 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
