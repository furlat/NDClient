extends "res://assets/vfx/extensions/spirit-receiver-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd"
const PHASE := "res://assets/vfx/extensions/spirit-receiver-20261022/sources/07bdd89007c0d0e191d6/necrotic.tres"

static func make_component(input: Dictionary) -> Node3D:
	var actual := input.duplicate(true)
	actual.phase = load(PHASE)
	return load("res://assets/vfx/extensions/spirit-receiver-20261022/sources/7c7b158e666a62dfa651/common_occurrence.gd").make_component(actual)
