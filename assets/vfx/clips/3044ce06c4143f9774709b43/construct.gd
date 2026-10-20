extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3044ce06c4143f9774709b43/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6d2ecca9485bdaead214/1c9f9e3b5df285ad.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
