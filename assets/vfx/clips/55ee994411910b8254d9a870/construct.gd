extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/55ee994411910b8254d9a870/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e2797c59010feeda2574/7ece7a58dfa0278f.tres"
	return instance

func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
