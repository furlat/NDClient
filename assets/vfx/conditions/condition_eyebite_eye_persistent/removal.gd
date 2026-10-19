extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_eyebite_eye_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_eyebite_eye_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/FactoryGenerated_0000_MeshInstance3D"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "live_pose": {"camera_blend": 0.32, "mode": "gaze", "nodes": ["assembly/effect/Donor/FactoryGenerated_0000_MeshInstance3D"], "offset": [0.0, 1.01823376490863, 0.0]}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
