extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6f821516cfca26e77c306415/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/24de86e2cd782dc04a31/native_target_initial.tres"
	return instance


func set_native_state(value: Variant) -> void:
	forward("set_native_state", value)
