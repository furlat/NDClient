extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_vitriolic_residue_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_vitriolic_residue_persistent/prepared.scn", "geometry": ["effect/ActualRecipientCorrosion0", "effect/ActualRecipientCorrosion1", "effect/ActualRecipientCorrosion2", "effect/ActualRecipientCorrosion3", "effect/ActualRecipientCorrosion4", "effect/ActualRecipientCorrosion5", "effect/ActualRecipientCorrosion6", "effect/ActualRecipientCorrosion7", "effect/ActualRecipientCorrosion8", "effect/ActualRecipientCorrosion9"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "droplets", "settings": {"candidate_radius_cells": 0.46, "count": 10.0, "nodes": ["ActualRecipientCorrosion*"], "profile": 1.0}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
