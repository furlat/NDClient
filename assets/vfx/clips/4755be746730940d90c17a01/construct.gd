extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4755be746730940d90c17a01/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/a8466d6d38bb001e3996/760c21aca1a9bed9.tres"
	return instance

func set_transition_events(value: Variant) -> void:
	forward("set_transition_events", value)
