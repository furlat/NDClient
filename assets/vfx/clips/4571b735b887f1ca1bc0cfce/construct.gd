extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4571b735b887f1ca1bc0cfce/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/fd4aac48e6a6ad9b1285/native_target2_residue.tres"
	return instance


func set_native_state(value: Variant) -> void:
	forward("set_native_state", value)
