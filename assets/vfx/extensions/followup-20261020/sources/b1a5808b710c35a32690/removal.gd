extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/b1a5808b710c35a32690/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_aegis_spark_persistent/prepared.scn", "geometry": ["effect/OriginalCompactShieldPanel"], "emitters": [], "application_seconds": 0.24, "removal_seconds": 0.2, "loop_seconds": 4.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "forms", "settings": {"fraction_max": 0.88, "fraction_min": 0.46, "geometry_slots": ["body", "chest", "cloak"], "height_cap_cells": 0.2, "readable": false, "width_cap_cells": 0.16}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
