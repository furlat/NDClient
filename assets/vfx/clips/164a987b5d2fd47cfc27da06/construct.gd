extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/164a987b5d2fd47cfc27da06/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/b61c0a9cd95777f96557/ad825e90b0cd3733.tres"
	return instance


func set_weapon_binding(value: Variant) -> void:
	forward("set_weapon_binding", value)
