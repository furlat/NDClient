extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_freedom_of_movement_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_freedom_of_movement_persistent/prepared.scn", "geometry": ["assembly/effect/Donor/FreedomStream0", "assembly/effect/Donor/FreedomStream1", "assembly/effect/Donor/FreedomStream2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 628.318530717959, "sustain_gain": 1.0, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
