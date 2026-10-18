extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/a0a89cb030ff4640a60fc016/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/4fabb29e98f91acabd18/f7108fc4826eb7a1.tres"
	return instance


func set_enchantment_input(value: Variant) -> void:
	forward("set_enchantment_input", value)
