extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e332b8924c6f407323f6e765/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4fe6d14d770e411aec4a/detonation_saved_armed.tres"
	return instance


func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
