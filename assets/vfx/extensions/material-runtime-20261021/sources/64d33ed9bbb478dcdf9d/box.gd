extends "res://assets/vfx/extensions/material-runtime-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/3dcb6288ad2b0a017239/box.tres"

static func make_component(input: Dictionary) -> Node3D:
	var parameters := input.duplicate(true)
	parameters.phase = VfxPackageIO_64d33ed9bb.resource(PHASE)
	return VfxPackageIO_64d33ed9bb.resource("res://assets/vfx/extensions/material-runtime-20261021/sources/99f1d493f68d090d7e35/observed_forcecage_occurrence.gd").make_component(parameters)

const VfxPackageIO_64d33ed9bb = preload("res://assets/vfx/extensions/material-runtime-20261021/scoped_resource_io.gd")
