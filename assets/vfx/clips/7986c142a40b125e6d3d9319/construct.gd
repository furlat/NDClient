extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7986c142a40b125e6d3d9319/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/ff3b3f6ba70efa4aa91d/0eb1d51908db097c.tres"
	return instance

func set_admitted_cells(value: Variant) -> void:
	forward("set_admitted_cells", value)

func set_retirement_time(value: Variant) -> void:
	forward("set_retirement_time", value)
