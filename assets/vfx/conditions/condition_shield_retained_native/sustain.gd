extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_shield_retained_native/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_shield_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/ShieldSphere_1"], "emitters": [], "application_seconds": 0.18, "removal_seconds": 0.3, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
