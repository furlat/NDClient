extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d33bb3edee190cd2904bc944/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/9f5b9bf91ea7d2bed1ca/c59880413a9d1aa5.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
