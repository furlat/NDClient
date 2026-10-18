extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c036e961997aac7d2a6ceb91/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/44f9b7d018956f0ea11d/fire_trigger.tres"
	return instance


func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
