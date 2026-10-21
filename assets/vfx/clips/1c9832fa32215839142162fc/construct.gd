extends "res://assets/vfx/extensions/input-reduction-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1c9832fa32215839142162fc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/input-reduction-20261021/sources/7af1dfa5616330f068ef/8fcd345672c6929a.tres").to_clip()
	return instance
