extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2b4714fa15e3a6e7f359c1dd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/40bfe67606ab1be78095/acid_trigger.tres"
	return instance


func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
