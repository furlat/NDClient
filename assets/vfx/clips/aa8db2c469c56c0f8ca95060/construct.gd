extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/aa8db2c469c56c0f8ca95060/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b8f9917eac7a38cb2a4e/256ffa5d49717446.tres"
	return instance

func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
