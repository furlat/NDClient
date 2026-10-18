extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/494d232978fa44f2ee13cc78/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/164786cdeda8e1178000/fdb376ceb46cddc9.tres"
	return instance


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
