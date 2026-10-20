extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/b52cd344b64d579c1914936e/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/4d18629e4b2ff85eda7e/2037077a213c0ef8.tres"
	return instance
