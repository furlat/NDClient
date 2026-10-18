extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/bd0cd1319f2669a84cb4f5de/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/470b3dc7d5131529ac5f/00.tres"
	return instance


func set_cancellation_observation(value: Variant) -> void:
	forward("set_cancellation_observation", value)
