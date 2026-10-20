extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/223240883e03c66b090a9bf0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ba15fbe3d0213cfa202e/bcaa7037fa4bfc59.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
