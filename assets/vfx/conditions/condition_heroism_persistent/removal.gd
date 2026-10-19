extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_heroism_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_heroism_persistent/prepared.scn", "geometry": ["support/SupportLayer0Vane0", "support/SupportLayer0Vane1", "support/SupportLayer0Vane2", "support/SupportLayer0Vane3"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 62.8318530717959, "sustain_gain": 1.0, "adaptive_surface": {"kind": "vanes", "settings": {"readable": false}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
