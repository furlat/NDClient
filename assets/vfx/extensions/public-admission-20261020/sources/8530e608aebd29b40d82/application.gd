extends "res://assets/vfx/extensions/public-admission-20261020/sources/9f0c9af7b2de5832937f/public_cadence.gd"
const Source = preload("res://assets/vfx/extensions/public-admission-20261020/sources/9f0c9af7b2de5832937f/public_cadence.gd")
const PHASE_DATA := "res://assets/vfx/extensions/public-admission-20261020/sources/c79bea7f21e15beecac7/application.tres"


static func preparation_resources(input: Dictionary) -> Array:
	var parameters: Dictionary = VfxPackageIO_8530e608ae.resource(PHASE_DATA).components[0].input.merged(input, true)
	return Source.preparation_resources(parameters)


static func make_component(input: Dictionary) -> Node3D:
	var parameters: Dictionary = VfxPackageIO_8530e608ae.resource(PHASE_DATA).components[0].input.merged(input, true)
	return Source.make_component(parameters)

const VfxPackageIO_8530e608ae = preload("res://assets/vfx/extensions/public-admission-20261020/scoped_resource_io.gd")
