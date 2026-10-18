extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b4181e0149d1218d8b5f5af9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0987b2a8f0ef2ae6d1ba/03.tres"
	return instance


func set_observation(value: Variant) -> void:
	forward("set_observation", value)
