extends "res://assets/vfx/extensions/heavy-effects-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/233a994bf9528a0d23dbbaf8/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/heavy-effects-20261020/sources/62acdb2f299514b70cd9/374f3823781bd261.tres"
	return instance
