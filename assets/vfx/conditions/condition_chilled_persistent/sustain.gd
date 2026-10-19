extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_chilled_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_chilled_persistent/prepared.scn", "geometry": ["effect/NativeReceivingMaterial"], "emitters": [], "application_seconds": 0.24, "removal_seconds": 0.2, "loop_seconds": 4.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"capacity": 8192.0, "clearance_cells": 0.003, "fraction_max": 0.97, "fraction_min": 0.15, "nodes": ["NativeReceivingMaterial"], "slot": "recipient_patch"}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
