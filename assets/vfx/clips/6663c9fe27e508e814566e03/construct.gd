extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6663c9fe27e508e814566e03/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/8323e85786c1246e7ed7/phase.tres"
	return instance


func set_reaction_observation(value: Variant) -> void:
	forward("set_reaction_observation", value)
