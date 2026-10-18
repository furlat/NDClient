extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/18924bdd0aca0ad43bcd0ae6/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/60bcf0b8a178e23d3a41/phase-0.tres"
	return instance


func set_operation_state(value: Variant) -> void:
	forward("set_operation_state", value)
