extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1fa6d92c2ef15f2e85e72ea8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bab77fa8b474325f348b/cold_trigger.tres"
	return instance


func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
