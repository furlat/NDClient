extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/8f571e8fd1fa59361cb6/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_shocked_persistent/prepared.scn", "geometry": ["network/MeasuredContactArcs1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 0.65, "adaptive_surface": {"kind": "electric_contact", "settings": {}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
