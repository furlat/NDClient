extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/01d77b5dfdf9846acf79b94c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/material-runtime-20261021/sources/dabbb5b33eff1fb6cd00/ability_burden.tres").to_clip()
	return instance
