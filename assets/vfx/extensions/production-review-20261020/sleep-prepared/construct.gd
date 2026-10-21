extends "res://assets/vfx/extensions/production-review-20261020/sources/6269f7f4cb5f43f5a59c/occurrence.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/production-review-20261020/sleep-prepared/construct.gd").new()
	instance.parameters = input.duplicate(true)
	instance.parameters.phase_path = "res://assets/vfx/extensions/production-review-20261020/sources/c981953c982755d11726/sleep-prepared.tres"
	return instance
