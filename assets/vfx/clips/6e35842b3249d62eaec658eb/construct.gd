extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6e35842b3249d62eaec658eb/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/83b575278423e968f08f/0130d3e3532c0e3f.tres"
	return instance


func set_accepted_release(value: Variant) -> void:
	forward("set_accepted_release", value)
