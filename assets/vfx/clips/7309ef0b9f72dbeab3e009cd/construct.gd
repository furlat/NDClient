extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7309ef0b9f72dbeab3e009cd/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/fa7f9bd856e2cc636c6b/corner-phase.tres"
	return instance

func set_visual_state(value: Variant) -> void:
	forward("set_visual_state", value)
