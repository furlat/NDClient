extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2e525bf1648db8f9117b4a3a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/7ece7a58dfa0278f9360/acid_armed.tres"
	return instance


func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
