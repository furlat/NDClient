extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7994849b8d36f21e4335afd6/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/219bd1eb2f9b5f923875/3d8e956de793a267.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
