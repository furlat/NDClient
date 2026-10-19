extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_ensnaring_vines_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_ensnaring_vines_persistent/prepared.scn", "geometry": ["owned_contact/MeasuredBarkVine0", "owned_contact/MeasuredBarkVine1", "owned_contact/MeasuredBarkVine2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "support", "settings": {"geometry_slots": ["body", "chest", "cloak", "legs", "shoes"], "vine_bounds": true}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
