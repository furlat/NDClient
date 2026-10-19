extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_protection_from_evil_and_good_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_protection_from_evil_and_good_persistent/prepared.scn", "geometry": ["receiving/ReceivingLayer0Curve0", "receiving/ReceivingLayer0Curve1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 4.18879020478639, "sustain_gain": 1.0, "adaptive_surface": {"kind": "curves", "settings": {"readable": false}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
