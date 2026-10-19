extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_bestow_curse_rings_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_bestow_curse_rings_persistent/prepared.scn", "geometry": ["assembly/rings_effect/Donor/LingeringCurseCircle0", "assembly/rings_effect/Donor/LingeringCurseCircle1", "assembly/rings_effect/Donor/LingeringCurseCircle2", "assembly/brand_effect/Donor/VFXStatusDark/Mesh", "assembly/brand_effect/Donor/VFXStatusDark/Particles", "assembly/brand_effect/Donor/VFXStatusDark/Aura", "assembly/brand_effect/Donor/VFXStatusDark/ParticlesLoopHalf", "assembly/brand_effect/Donor/VFXStatusDark/AuraLoopHalf"], "emitters": ["assembly/brand_effect/Donor/VFXStatusDark/Particles", "assembly/brand_effect/Donor/VFXStatusDark/Aura", "assembly/brand_effect/Donor/VFXStatusDark/ParticlesLoopHalf", "assembly/brand_effect/Donor/VFXStatusDark/AuraLoopHalf"], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"head_clearance_cells": 0.53, "head_groups": [], "kind": "height_fit", "reference_height_cells": 1.72}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
