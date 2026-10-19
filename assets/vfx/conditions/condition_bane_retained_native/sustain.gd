extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_bane_retained_native/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_bane_retained_native/prepared.scn", "geometry": ["effect/Retained/Donor/OrbitBrand0", "effect/Retained/Donor/CurseWisp00", "effect/Retained/Donor/CurseWisp01", "effect/Retained/Donor/BloodTear00", "effect/Retained/Donor/BloodTear01", "effect/Retained/Donor/OrbitBrand1", "effect/Retained/Donor/CurseWisp10", "effect/Retained/Donor/CurseWisp11", "effect/Retained/Donor/BloodTear10", "effect/Retained/Donor/BloodTear11", "effect/Retained/Donor/OrbitBrand2", "effect/Retained/Donor/CurseWisp20", "effect/Retained/Donor/CurseWisp21", "effect/Retained/Donor/BloodTear20", "effect/Retained/Donor/BloodTear21"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.5, "loop_seconds": 6.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
