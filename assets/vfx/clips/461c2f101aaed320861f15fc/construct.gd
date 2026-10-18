extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/461c2f101aaed320861f15fc/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0faeca76ac4946f1dc93/04.tres"
	return instance


func set_observation(value: Variant) -> void:
	forward("set_observation", value)
