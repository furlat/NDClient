extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_branding_smite_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_branding_smite_persistent/prepared.scn", "geometry": ["smite/MeasuredRevealedBrand", "smite/OpeningBrandStroke0", "smite/OpeningBrandStroke1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"capacity": 8192.0, "clearance_cells": 0.01, "nodes": ["MeasuredRevealedBrand"], "slot": "recipient_patch"}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
