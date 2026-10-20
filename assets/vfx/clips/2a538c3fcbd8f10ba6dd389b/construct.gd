extends "res://assets/vfx/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/clips/2a538c3fcbd8f10ba6dd389b/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/late-20261020/sources/aea8f3f23c6a51b06400/74438c285178fd24.tres"
	return instance
