extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/73b1ab8a38dd4c255fd64cfe/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b723569a33e219f97f5d/thunder_trigger.tres"
	return instance


func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
