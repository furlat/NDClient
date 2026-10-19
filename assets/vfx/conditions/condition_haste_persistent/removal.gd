extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_haste_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_haste_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/SmCylinder3"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.2, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
