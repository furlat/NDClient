extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/0fcc7c675f760768a6c92aa0/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4d5d70ae7816ca951c94/c944b8a13d57b986.tres"
	return instance


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
