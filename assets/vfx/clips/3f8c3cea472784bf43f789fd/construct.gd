extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3f8c3cea472784bf43f789fd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bf2d5f970dea8aef01a1/79c332f0bc1bfa8a.tres"
	return instance

func set_event_binding(value: Variant) -> void:
	forward("set_event_binding", value)

func set_event_state(value: Variant) -> void:
	forward("set_event_state", value)
