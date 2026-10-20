extends "res://assets/vfx/extensions/followup-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b5b835f0d59555eab9f58118/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/followup-20261020/sources/6f108e387e501d745230/call_live_strike.tres"
	return instance

func set_density_field(value: Variant) -> void:
	forward("set_density_field", value)

func set_link_edges(value: Variant) -> void:
	forward("set_link_edges", value)
