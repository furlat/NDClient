extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_phantasmal_force_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_phantasmal_force_persistent/prepared.scn", "geometry": ["receiving/ReceivingLayer0Curve0", "receiving/ReceivingLayer0Curve1", "receiving/ReceivingLayer1Curve0", "receiving/ReceivingLayer1Curve1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.73181969877373, "sustain_gain": 1.0, "adaptive_surface": {"kind": "curves", "settings": {"readable": false}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
