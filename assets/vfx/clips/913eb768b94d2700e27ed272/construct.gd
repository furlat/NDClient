extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/913eb768b94d2700e27ed272/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/0bd814af7e06484e6851/f18764e34ab699f0.tres"
	return instance


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
