extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/f9c5a8dd550a964c9c08d174/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/d7953cda75514aae063b/00.tres"
	return instance


func set_review_contacts(value: Variant) -> void:
	forward("set_review_contacts", value)


func set_visual_occupants(value: Variant) -> void:
	forward("set_visual_occupants", value)


func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)
