extends "res://assets/vfx/extensions/material-runtime-20261021/sources/59e01d16319a5dcc3e14/constructed_occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/3d5b0afcf75336469b495637/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.clip = load("res://assets/vfx/extensions/material-runtime-20261021/sources/907ebdb1975e9b2d65a9/necrotic_wound.tres").to_clip()
	return instance
