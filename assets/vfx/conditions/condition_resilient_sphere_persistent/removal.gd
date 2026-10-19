extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_resilient_sphere_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_resilient_sphere_persistent/prepared.scn", "geometry": ["field/RecipientForceBoundary"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "sphere", "settings": {"clearance_cells": 0.12, "reference_radius_cells": 1.0244335243676}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
