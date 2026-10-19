extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_bestow_curse_inaction_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_bestow_curse_inaction_persistent/prepared.scn", "geometry": ["assembly/brand_effect/Donor/FactoryGenerated_0001_Node3D/CurseChoice3", "assembly/brand_effect/Donor/BaneDerivedWisp0", "assembly/brand_effect/Donor/BaneDerivedWisp1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"head_clearance_cells": 0.53, "head_groups": ["assembly/brand_effect/Donor/FactoryGenerated_0001_Node3D"], "kind": "height_fit", "reference_height_cells": 1.72}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
