extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/264aae96765d5d849c0c2387/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ac7b4d1bde1639e35c7f/b11257abe45abe65.tres"
	return instance

func set_event_binding(value: Variant) -> void:
	forward("set_event_binding", value)

func set_event_state(value: Variant) -> void:
	forward("set_event_state", value)
