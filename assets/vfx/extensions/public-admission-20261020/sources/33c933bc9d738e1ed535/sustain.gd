extends "res://assets/vfx/extensions/public-admission-20261020/sources/9f0c9af7b2de5832937f/public_cadence.gd"
const Source = preload("res://assets/vfx/extensions/public-admission-20261020/sources/9f0c9af7b2de5832937f/public_cadence.gd")
const PHASE_DATA := "res://assets/vfx/extensions/public-admission-20261020/sources/57cd14efc53906ce3a06/sustain.tres"


static func preparation_resources(input: Dictionary) -> Array:
	var parameters: Dictionary = VfxPackageIO_33c933bc9d.resource(PHASE_DATA).components[0].input.merged(input, true)
	return Source.preparation_resources(parameters)


static func make_component(input: Dictionary) -> Node3D:
	var parameters: Dictionary = VfxPackageIO_33c933bc9d.resource(PHASE_DATA).components[0].input.merged(input, true)
	return Source.make_component(parameters)

const VfxPackageIO_33c933bc9d = preload("res://assets/vfx/extensions/public-admission-20261020/scoped_resource_io.gd")
