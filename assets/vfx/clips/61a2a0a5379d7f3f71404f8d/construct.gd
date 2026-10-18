extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/61a2a0a5379d7f3f71404f8d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/1958b122d64af2e60d0f/launch_target_packet.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
