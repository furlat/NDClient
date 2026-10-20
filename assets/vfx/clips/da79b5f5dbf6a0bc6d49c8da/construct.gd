extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/da79b5f5dbf6a0bc6d49c8da/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d677524b672f318af06a/2a1dce2ec9b046b2.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
