extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/spatial_web_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/spatial_web_persistent/prepared.scn", "geometry": ["effect/ContinuousSourceNet"], "emitters": [], "application_seconds": 1.8, "removal_seconds": 0.55, "loop_seconds": 2.0, "sustain_gain": 1.0, "cell_mask": true, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
