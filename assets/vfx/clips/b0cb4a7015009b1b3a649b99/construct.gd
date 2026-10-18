extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b0cb4a7015009b1b3a649b99/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0e0e341664ae3b60c69e/phase-0.tres"
	return instance


func set_cast_observation(value: Variant) -> void:
	forward("set_cast_observation", value)
