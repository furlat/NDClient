extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/477d2f8c611bc7012fab59b1/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6492c285efa3d5e7d81e/147035aa0088ea55.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
