extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b53a738100fe7b865f03b22a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/43dc7f52726667a940b4/94590e66751e15e4.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
