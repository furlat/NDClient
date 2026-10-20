extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/7397c8c1bba404aa7e66/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_shocked_persistent/prepared.scn", "geometry": ["network/MeasuredContactArcs1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.65, "adaptive_surface": {"kind": "electric_contact", "settings": {}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
