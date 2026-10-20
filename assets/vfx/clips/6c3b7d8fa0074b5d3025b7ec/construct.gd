extends "res://assets/vfx/extensions/followup-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/6c3b7d8fa0074b5d3025b7ec/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/followup-20261020/sources/a89d8b1cbfee64f8c8dd/339a3786b1c9bc8b2fb9.tres"
	return instance
