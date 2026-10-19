extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_aid_retained_native/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_aid_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/Mesh"], "emitters": [], "application_seconds": 1.1, "removal_seconds": 0.5, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
