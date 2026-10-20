extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d57eb7bac31bfb5f176c9836/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d7ef5c9794c8d5ff73a6/bab77fa8b474325f.tres"
	return instance

func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
