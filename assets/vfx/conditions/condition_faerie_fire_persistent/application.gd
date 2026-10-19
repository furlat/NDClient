extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_faerie_fire_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_faerie_fire_persistent/prepared.scn", "geometry": ["outline/ArticulatedFeyOutline0"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "contour", "settings": {"capacity": 8192.0, "width_cells": 0.014}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
