extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c1ec879b740524cfdfa02149/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/2b881cd36ed57e00d98b/miss_created_item.tres"
	return instance


func set_created_item_binding(value: Variant) -> void:
	forward("set_created_item_binding", value)
