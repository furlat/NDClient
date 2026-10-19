extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_arcane_sword_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_arcane_sword_persistent/prepared.scn", "geometry": ["field/IndependentArcaneSword", "field/FactualForcePressure0", "field/FactualForcePressure1", "field/FactualForcePressure2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "live_pose": {"mode": "translate", "nodes": ["field/IndependentArcaneSword"], "offset": [0.0, 0.35, 0.0]}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
