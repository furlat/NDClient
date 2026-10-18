extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"


static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/197c2f03fc0d602ba4276c89/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/sources/44bbeac4011755c87070/phase-0.tres"
	return instance


func set_link_edges(value: Variant) -> void:
	forward("set_link_edges", value)


func set_density_field(value: Variant) -> void:
	forward("set_density_field", value)
