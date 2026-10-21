extends "res://assets/vfx/extensions/material-runtime-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/935a8199cd9007d69ba6/cage.tres"

static func make_component(input: Dictionary) -> Node3D:
	var parameters := input.duplicate(true)
	parameters.phase = VfxPackageIO_dd5fa40c87.resource(PHASE)
	return VfxPackageIO_dd5fa40c87.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd").make_component(parameters)

const VfxPackageIO_dd5fa40c87 = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
