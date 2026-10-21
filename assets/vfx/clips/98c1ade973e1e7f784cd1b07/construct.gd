extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spirit-runtime-20261021/sources/53af195b70b841a65a63/radiant.tres"

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = load(PHASE)
	return load("res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)
