extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/4ada0f93507b80652784890e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/90677e5514209a0b6857/native_created_item.tres"
	return instance


func set_created_item_binding(value: Variant) -> void:
	forward("set_created_item_binding", value)
