extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_barkskin_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_barkskin_persistent/prepared.scn", "geometry": [], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "actor_operation": {"data": {"texture": "res://assets/vfx/shared/textures/a377773c2f1eb6ef6da5c31dab8cf7589087deaba24510effaaccf37c7a56317.res"}, "kind": 1.0, "loop_seconds": 2.0}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
