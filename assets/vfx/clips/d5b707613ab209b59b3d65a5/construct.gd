extends "res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spirit-runtime-20261021/sources/d08891dcb9d9d4e5e692/necrotic.tres"

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = load(PHASE)
	return load("res://assets/vfx/extensions/spirit-runtime-20261021/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)
