extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/633628e050d9e9588e085209/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/329af9c390cf410366ee/064d6e0e2ab5fde2.tres"
	return instance

func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
