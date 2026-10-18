extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/760a0de7da7cfa7179807b48/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/56f4809ccf5263d05c2b/00.tres"
	return instance


func set_observation(value: Variant) -> void:
	forward("set_observation", value)
