extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e644e7ec346260fbe131989c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/9289c09429767a9addaf/2013a8f45ad24918.tres"
	return instance

func set_glyph_state(value: Variant) -> void:
	forward("set_glyph_state", value)
