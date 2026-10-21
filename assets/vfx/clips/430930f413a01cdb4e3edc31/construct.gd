extends "res://assets/vfx/extensions/speed-completion-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/430930f413a01cdb4e3edc31/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/speed-completion-20261021/sources/50c6431ae75e5470855d/8fcd345672c6929a.tres").to_clip()
	return instance
