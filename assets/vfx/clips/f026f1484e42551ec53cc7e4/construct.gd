extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f026f1484e42551ec53cc7e4/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/2f78ce9900c8a7b64b65/counterspell.tres"
	return instance

func set_cancellation_observation(value: Variant) -> void:
	forward("set_cancellation_observation", value)
