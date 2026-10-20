extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/52eaf898c651d8617c26d364/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/21aa0a45f6cc1fc3d581/053de7d23404eb5a.tres"
	return instance

func set_damage_event(value: Variant) -> void:
	forward("set_damage_event", value)
