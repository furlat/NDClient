extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/ad8ed86333c1ce761488f25e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/12f7ce7f306465f19187/b706ac01565bbf49.tres"
	return instance

func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
