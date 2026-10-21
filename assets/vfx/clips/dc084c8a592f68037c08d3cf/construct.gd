extends "res://assets/vfx/extensions/speed-completion-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/dc084c8a592f68037c08d3cf/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/speed-completion-20261021/sources/ee60d32954653c691f23/e022ccf45fa38223.tres").to_clip()
	return instance
