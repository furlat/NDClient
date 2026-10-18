extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0872708bdfe8e3141babe79d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/064d6e0e2ab5fde25d9c/fire_native_exhale.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
