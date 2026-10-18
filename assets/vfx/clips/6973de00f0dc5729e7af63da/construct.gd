extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6973de00f0dc5729e7af63da/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/659b4a241593e8ab863a/launch_target2_packet.tres"
	return instance


func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
