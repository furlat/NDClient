extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f1e5d9f3e20beeec52fb1662/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/f83e91637ad0163f45bf/concentration_end_body.tres"
	return instance

func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
