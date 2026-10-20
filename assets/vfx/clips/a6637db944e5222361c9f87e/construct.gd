extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a6637db944e5222361c9f87e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0fc56cd63fb1ffba7f21/82e7e1a614ce10d6.tres"
	return instance

func set_event_binding(value: Variant) -> void:
	forward("set_event_binding", value)

func set_event_state(value: Variant) -> void:
	forward("set_event_state", value)
