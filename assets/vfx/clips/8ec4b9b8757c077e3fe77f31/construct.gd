extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/8ec4b9b8757c077e3fe77f31/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/01190cb6ba5d8f991ad6/cd6455c4f89b816e.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
