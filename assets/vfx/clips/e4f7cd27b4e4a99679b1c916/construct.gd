extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e4f7cd27b4e4a99679b1c916/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/ef8fe2141761f4f25a4c/doused_trail_body.tres"
	return instance

func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
