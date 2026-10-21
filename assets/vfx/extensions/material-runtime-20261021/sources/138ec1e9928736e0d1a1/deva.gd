extends RefCounted
const Source = preload("res://assets/vfx/extensions/material-runtime-20261021/sources/6e80c5542129b887652b/fixed_source.gd")
const PHASE := "res://assets/vfx/extensions/material-runtime-20261021/sources/ee2f010c497771da80c7/deva.tres"


static func preparation_resources(_input: Dictionary) -> Array:
	return Source.preparation_resources(PHASE)


static func make_component(input: Dictionary) -> Node3D:
	return Source.make(PHASE, input)
