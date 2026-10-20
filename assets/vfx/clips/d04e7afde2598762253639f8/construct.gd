extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d04e7afde2598762253639f8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/94630a63a5ebe044dca9/4fe6d14d770e411a.tres"
	return instance

func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
