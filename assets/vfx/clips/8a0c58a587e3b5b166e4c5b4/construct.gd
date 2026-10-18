extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8a0c58a587e3b5b166e4c5b4/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8249653a607de607c776/2fb3ab2147710211.tres"
	return instance


func set_surface_records(value: Variant) -> void:
	forward("set_surface_records", value)
