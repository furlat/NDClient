extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8e46045b4b59d8d968e7414d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/462574f5d5aee1c10095/12b41213bea06ae4.tres"
	return instance

func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
