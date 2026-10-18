extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3f2dfc10a2a9034984d6f512/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8e5126aee0ed7098ee9e/suppressed_armed.tres"
	return instance


func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
