extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/9e0e5f6c9f049255898c9fe1/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/01cd2be93080d3aa46b2/phase.tres"
	return instance


func set_reaction_observation(value: Variant) -> void:
	forward("set_reaction_observation", value)
