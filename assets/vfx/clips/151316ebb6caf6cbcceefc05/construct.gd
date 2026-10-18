extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/151316ebb6caf6cbcceefc05/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/6bd1a45c7aebb9dc7326/72acf0e9dcab465e.tres"
	return instance


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
