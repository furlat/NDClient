extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_hunters_mark_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_hunters_mark_persistent/prepared.scn", "geometry": ["owned_quarry/ActualQuarryForkedTrackingCuts", "owned_quarry/ActualQualifiedWeaponFootprint", "owned_quarry/SourceHandTrackingFork0", "owned_quarry/SourceHandTrackingFork1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"capacity": 8192.0, "clearance_cells": 0.012, "nodes": ["ActualQuarryForkedTrackingCuts"], "slot": "recipient_patch"}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
