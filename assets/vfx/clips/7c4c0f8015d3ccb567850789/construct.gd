extends "res://assets/vfx/extensions/input-reduction-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/7c4c0f8015d3ccb567850789/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/input-reduction-20261021/sources/8e1bc02b83b153a2f55e/counterspell.tres").to_clip()
	return instance
