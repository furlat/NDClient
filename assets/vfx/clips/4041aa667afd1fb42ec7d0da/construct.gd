extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4041aa667afd1fb42ec7d0da/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/760c21aca1a9bed99f13/00.tres"
	return instance


func set_transition_events(value: Variant) -> void:
	forward("set_transition_events", value)
