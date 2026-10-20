extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a71a21c96eebc6a0d378e2c9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a9131c02cec0a94ede7a/ca1beb9c6c5eb265.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
