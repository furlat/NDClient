extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/15c939d56546e6b7580e884c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/cd220675623bccea4bd6/2199c25d7dfde744.tres"
	return instance

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
