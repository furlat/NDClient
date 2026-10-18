extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/681fe4ebd96c12b98ae0c9f5/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d26af03338a59f2f10c3/native_target_packet.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
