extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_burning_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_burning_persistent/prepared.scn", "geometry": ["smite/ExactWeaponFireContact", "smite/MeasuredRecipientScorch", "smite/SourceFireTongue0", "smite/SourceFireTongue1", "smite/SourceFireTongue2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0943951023932, "sustain_gain": 1.0, "adaptive_surface": {"kind": "compound", "layers": [{"kind": "measured", "settings": {"clearance_cells": 0.009, "nodes": ["MeasuredRecipientScorch"], "slot": "recipient_patch"}}, {"kind": "support", "settings": {"fraction_max": 0.8, "fraction_min": 0.43, "geometry_slots": ["body", "chest", "cloak"]}}]}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
