extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6753950be9fd9b2fbda7e882/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/a8fc564404b2691dbfb0/target_native_next_end_packet.tres"
	return instance


func set_native_state(value: Variant) -> void:
	forward("set_native_state", value)
