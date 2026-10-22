extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2e841cd3fe433b14771705fc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/2bf73a9aa3a899bbfe2a/87f3b8e0852cfbcf.tres").to_clip()
	return instance
