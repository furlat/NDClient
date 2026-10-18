extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/454add2e0cc5796c57241d56/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ff4553114da2a5f78b92/detonation_trigger.tres"
	return instance


func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
