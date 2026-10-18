extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0b92e0844a9abe88294dc70e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bcaa7037fa4bfc592bcd/fire_self_grant.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
