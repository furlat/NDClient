extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/73aaa2b1ca4bdcd78d4f774d/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/df1c2cdaabe143e07011/surface_blood_freeze_thaw-phase.tres"
	return instance
