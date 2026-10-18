extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6e935e221c4ccbc35662e7f9/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/9c546fdc02c27c9fa89f/0d4ce405890ba0f1.tres"
	return instance


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
