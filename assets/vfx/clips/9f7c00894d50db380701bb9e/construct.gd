extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/9f7c00894d50db380701bb9e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/eef815aa81c248c12ba0/c454df148f90a76c.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
