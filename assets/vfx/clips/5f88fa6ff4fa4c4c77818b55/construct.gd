extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/5f88fa6ff4fa4c4c77818b55/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e1c92f45178145257769/6ad4df5d3f3fc453.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
