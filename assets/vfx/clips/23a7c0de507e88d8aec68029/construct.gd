extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/23a7c0de507e88d8aec68029/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/522f79eaa375f3c450d7/doused_trail_body.tres"
	return instance


func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
