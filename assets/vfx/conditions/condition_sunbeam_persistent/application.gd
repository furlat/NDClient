extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_sunbeam_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_sunbeam_persistent/prepared.scn", "geometry": ["effect/MaintainedSolarHandOrb"], "emitters": [], "application_seconds": 0.18, "removal_seconds": 0.15, "loop_seconds": 1000.0, "sustain_gain": 1.0, "live_pose": {"mode": "anchor", "nodes": ["effect/MaintainedSolarHandOrb"], "offset": [0.0, 0.0, 0.0]}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
