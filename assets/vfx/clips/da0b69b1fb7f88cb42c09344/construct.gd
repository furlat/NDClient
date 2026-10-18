extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/da0b69b1fb7f88cb42c09344/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/df12582ccc66ddaa0f6f/01d1d16ac15a2a2d.tres"
	return instance


func set_owner_projection(value: Variant) -> void:
	forward("set_owner_projection", value)


func set_activation_projection(value: Variant) -> void:
	forward("set_activation_projection", value)
