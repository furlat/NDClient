extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_hex_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_hex_persistent/prepared.scn", "geometry": ["owned_quarry/ActualQuarryThreeCurseCuts", "owned_quarry/InwardCurseContact0", "owned_quarry/InwardCurseContact1", "owned_quarry/InwardCurseContact2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"capacity": 8192.0, "clearance_cells": 0.012, "colour_alpha_sine": {"amplitude": 0.06, "base": 0.48, "rate": 2.0, "rgb": [0.68, 0.27, 0.36]}, "fraction_max": 0.9, "fraction_min": 0.28, "nodes": ["ActualQuarryThreeCurseCuts"], "readability": {"alpha_gain": 4.0, "emission_gain": 0.65, "output_linear_rgb": [0.52, 0.055, 0.03]}, "slot": "recipient_patch"}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
