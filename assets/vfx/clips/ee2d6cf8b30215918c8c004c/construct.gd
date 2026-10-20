extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/ee2d6cf8b30215918c8c004c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a416ed4c70facdd8b3b1/c89f5a23a9e33f87.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
