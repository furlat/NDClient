extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/86dba5e35365d33f77928d2a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/796c8711544f39b91905/ad6e239a3b68bba8.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
