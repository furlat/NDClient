extends RefCounted
const Source = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/6e80c5542129b887652b/fixed_source.gd")
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/02aad722b95dce013dde/draconic_spirit.tres"


static func preparation_resources(_input: Dictionary) -> Array:
	return Source.preparation_resources(PHASE)


static func make_component(input: Dictionary) -> Node3D:
	return Source.make(PHASE, input)
