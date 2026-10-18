extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/60c155ed7c35654f51e559cf/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/3b4ad8ce3bfde31c28f5/02.tres"
	return instance


func set_observation(value: Variant) -> void:
	forward("set_observation", value)
