extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/cf112bb813593ae246727c0e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4a45155cfdb7913195ce/b723569a33e219f9.tres"
	return instance

func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
