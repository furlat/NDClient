extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_bless_retained_native/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_bless_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/Mesh", "effect/Retained/Donor/BrokenGroundBlessing"], "emitters": [], "application_seconds": 0.5, "removal_seconds": 0.5, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
