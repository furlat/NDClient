extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/150a4d53d96303cc0f9e265f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/cloud-body-speed-20261021/sources/071f7f74bedf15d3fcfd/8fcd345672c6929a.tres").to_clip()
	return instance
