extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/44e6939e354f50f809887acf/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/332e3c21201500624e24/phase-0.tres"
	return instance


func set_cast_observation(value: Variant) -> void:
	forward("set_cast_observation", value)
