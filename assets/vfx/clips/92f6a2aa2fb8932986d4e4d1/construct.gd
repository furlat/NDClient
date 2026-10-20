extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/92f6a2aa2fb8932986d4e4d1/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/bc0ed85368be11f50a56/374f3823781bd261.tres"
	return instance
