extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/213eda1ff311d799e0e3eef7/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/material-runtime-20261021/sources/74c3c820027ac282cd40/bent_strike.tres").to_clip()
	return instance
