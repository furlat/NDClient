extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/baf14533560e4322f9103abd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6941881cc72eee10c968/fire_armed.tres"
	return instance


func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
