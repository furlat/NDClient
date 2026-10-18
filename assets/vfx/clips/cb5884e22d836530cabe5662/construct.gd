extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/cb5884e22d836530cabe5662/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e809ea9728957b992b14/rest_armed.tres"
	return instance


func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
