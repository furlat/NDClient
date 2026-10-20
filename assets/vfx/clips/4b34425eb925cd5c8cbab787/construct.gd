extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4b34425eb925cd5c8cbab787/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/e281236451f29664e322/ae0e411cdf7b3eb8.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
