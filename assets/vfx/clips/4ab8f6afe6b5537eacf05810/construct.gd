extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4ab8f6afe6b5537eacf05810/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/f08820af40576698ac57/native_body.tres"
	return instance


func set_body_state(value: Variant) -> void:
	forward("set_body_state", value)
