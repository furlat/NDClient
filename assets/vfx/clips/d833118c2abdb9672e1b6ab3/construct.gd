extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/d833118c2abdb9672e1b6ab3/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/bef5db7f177d6d60280f/672d6556658cbc67.tres"
	return instance

func set_owner_visibility(value: Variant) -> void:
	forward("set_owner_visibility", value)
