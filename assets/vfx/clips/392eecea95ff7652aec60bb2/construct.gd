extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/392eecea95ff7652aec60bb2/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/58921737ffbcd92488ea/a88df2fc88183a0f.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
