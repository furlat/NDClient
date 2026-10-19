extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_petrified_body_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_petrified_body_persistent/prepared.scn", "geometry": [], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "actor_operation": {"capture_pose": true, "data": {"colours": [3092523.0, 5132357.0, 7698277.0, 10526339.0, 13419939.0], "texture": "res://assets/vfx/shared/textures/ed5ae895cbbe3aebc20094e8b5e7ba3553f0ab93f7e93ca1fa85f72482efaef1.res", "texture_repeats": 6.0, "texture_weight": 0.35}, "kind": 3.0, "loop_seconds": 2.0}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
