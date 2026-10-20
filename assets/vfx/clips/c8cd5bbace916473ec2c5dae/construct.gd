extends "res://assets/vfx/extensions/followup-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/c8cd5bbace916473ec2c5dae/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/followup-20261020/sources/68dd3a76c9d7830999e0/chain_live_branches.tres"
	return instance

func set_density_field(value: Variant) -> void:
	forward("set_density_field", value)

func set_link_edges(value: Variant) -> void:
	forward("set_link_edges", value)
