extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e2fafae6d9811e1c0c13ab17/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/f935a7716ce443c596e5/contact_phase.tres"
	return instance


func set_suppressed(value: Variant) -> void:
	forward("set_suppressed", value)
