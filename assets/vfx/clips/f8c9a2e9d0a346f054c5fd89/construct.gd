extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f8c9a2e9d0a346f054c5fd89/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/32d013e8376b912f31f5/native_target2_packet.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
