extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spike-readiness-20261022/sources/5ccb02815e601fa3218f/phase.tres"

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = load(PHASE)
	return load("res://assets/vfx/extensions/spike-readiness-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)
