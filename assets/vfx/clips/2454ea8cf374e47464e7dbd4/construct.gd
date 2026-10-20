extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2454ea8cf374e47464e7dbd4/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b4c5424822d524afd5bf/9d5db0a3b62e9537.tres"
	return instance

func set_trigger_event(value: Variant) -> void:
	forward("set_trigger_event", value)
