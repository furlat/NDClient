extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/aec4dcec81ee7b6f0227fe77/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/2b8848badd8341ae5796/9bf84028824a8089.tres"
	return instance


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
