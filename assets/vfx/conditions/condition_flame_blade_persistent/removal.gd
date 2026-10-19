extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_flame_blade_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_flame_blade_persistent/prepared.scn", "geometry": ["effect/ActualCreatedItemMeasuredFire", "effect/AttachedNativeBladeFlame0", "effect/AttachedNativeBladeFlame1", "effect/AttachedNativeBladeFlame2", "effect/AttachedNativeBladeFlame3", "effect/AttachedNativeBladeFlame4", "effect/AttachedNativeBladeFlame5"], "emitters": [], "application_seconds": 0.18, "removal_seconds": 0.15, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "flame_blade", "settings": {"clearance_cells": 0.007, "nodes": ["ActualCreatedItemMeasuredFire"], "requires_equipped_item": true, "slot": "weapon"}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
