extends "res://assets/vfx/extensions/continuation42-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0c7f8fcb39a30d7671899500/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/continuation42-20261020/sources/dc3c1520b7a84e10b0a3/second_wind.tres"
	return instance

func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)
