extends "res://assets/vfx/extensions/speed-completion-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/50846437bddaac7c4bd0dbe7/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/speed-completion-20261021/sources/675814cf146b7889343b/87f3b8e0852cfbcf.tres").to_clip()
	return instance
