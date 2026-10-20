extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e2d4d2d2cce137ef5b1556d0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/50e80ca152a350dc272f/fbb7ce3f386bb8f1.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
