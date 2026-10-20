extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0c46d03585eddfb1f1ba12d7/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/9196df8ed1a64efc96ea/bc8d5819a63abf43.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
