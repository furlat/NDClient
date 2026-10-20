extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d12b576e1f885930c6a61fa4/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8c8df44c7b12e94cba2a/e8cfe22141c9b275.tres"
	return instance

func set_event_binding(value: Variant) -> void:
	forward("set_event_binding", value)

func set_event_state(value: Variant) -> void:
	forward("set_event_state", value)
