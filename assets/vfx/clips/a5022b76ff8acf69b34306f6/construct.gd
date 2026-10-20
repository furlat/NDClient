extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a5022b76ff8acf69b34306f6/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6d1939d597c1fab1d898/f3dce61f9679a0ec.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
