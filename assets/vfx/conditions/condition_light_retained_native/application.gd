extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_light_retained_native/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_light_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/Glow"], "emitters": [], "application_seconds": 0.2, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
