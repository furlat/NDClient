extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/1f1319865eff6c25ea982441/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/ced72a2281475393530f/bd8ff95fec323762.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
