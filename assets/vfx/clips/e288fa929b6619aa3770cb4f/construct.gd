extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/e288fa929b6619aa3770cb4f/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/7b01e8109eac2664d4d3/4f39e7da48cd5240.tres"
	return instance


func set_hit_input(value: Variant) -> void:
	forward("set_hit_input", value)


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
