extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e9e3473b5eed693795b8ed37/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0dad65638ef28faf5492/00.tres"
	return instance


func set_review_contacts(value: Variant) -> void:
	forward("set_review_contacts", value)


func set_visual_occupants(value: Variant) -> void:
	forward("set_visual_occupants", value)


func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)
