extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e8841d3ecc47ceb94869c5e8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/855d90bd751fe09926f7/target2_native_next_end_packet.tres"
	return instance


func set_native_state(value: Variant) -> void:
	forward("set_native_state", value)
