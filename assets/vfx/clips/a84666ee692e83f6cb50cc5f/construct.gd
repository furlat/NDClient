extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a84666ee692e83f6cb50cc5f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/273f8a2986e93a30288d/e5787906741222f8.tres"
	return instance

func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
