extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6496411cf68c5ad6f7f6d94c/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d36f9e2e66e273bb2e9d/fire_saved_exhale.tres"
	return instance


func set_grant_state(value: Variant) -> void:
	forward("set_grant_state", value)
