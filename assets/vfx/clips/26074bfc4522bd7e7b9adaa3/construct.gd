extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/26074bfc4522bd7e7b9adaa3/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d758b20e4184a2d45310/01.tres"
	return instance


func set_observation(value: Variant) -> void:
	forward("set_observation", value)
