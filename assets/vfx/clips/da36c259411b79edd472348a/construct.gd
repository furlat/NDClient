extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/da36c259411b79edd472348a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ebab6015fb1d74e271b0/3709fdac9fea7fb3.tres"
	return instance

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
