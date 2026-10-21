extends "res://assets/vfx/extensions/input-reduction-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f7706b17e4a2fcadbf94a078/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/input-reduction-20261021/sources/cd402eb2f0dbcf7aed26/e022ccf45fa38223.tres").to_clip()
	return instance
