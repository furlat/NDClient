extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_hideous_laughter_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_hideous_laughter_persistent/prepared.scn", "geometry": ["control/ReceivingLayer0Patch0", "control/ReceivingLayer0Patch1", "control/ReceivingLayer1Patch0", "control/ReceivingLayer1Patch1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 1.90399554763018, "sustain_gain": 1.0, "adaptive_surface": {"kind": "patches", "settings": {}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
