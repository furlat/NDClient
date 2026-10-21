extends "res://assets/vfx/extensions/input-reduction-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3d4fb28e3e50d7ec47dae03a/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/input-reduction-20261021/sources/15e773dfaa9a8ce240e5/normal.tres").to_clip()
	return instance
