extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_prone_native/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_prone_native/prepared.scn", "geometry": ["marker/Glyph"], "emitters": [], "application_seconds": 0.16, "removal_seconds": 0.25, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
