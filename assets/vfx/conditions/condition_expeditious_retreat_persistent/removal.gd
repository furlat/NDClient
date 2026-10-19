extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_expeditious_retreat_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_expeditious_retreat_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/windsoil"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
