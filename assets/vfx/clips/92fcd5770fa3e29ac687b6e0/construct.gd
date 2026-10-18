extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/92fcd5770fa3e29ac687b6e0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/f4c754a0465747edf0fc/00.tres"
	return instance


func set_review_contacts(value: Variant) -> void:
	forward("set_review_contacts", value)


func set_visual_occupants(value: Variant) -> void:
	forward("set_visual_occupants", value)


func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)
