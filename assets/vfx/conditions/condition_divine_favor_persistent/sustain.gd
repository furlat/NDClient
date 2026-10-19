extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_divine_favor_persistent/sustain.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_divine_favor_persistent/prepared.scn", "geometry": ["weapon_blessing/ActualEquippedItemSurface", "weapon_blessing/AppliedRadiantContactStroke0", "weapon_blessing/AppliedRadiantContactStroke1", "weapon_blessing/AppliedRadiantContactStroke2"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"clearance_cells": 0.006, "nodes": ["ActualEquippedItemSurface"], "requires_equipped_item": true, "slot": "weapon"}}, "phase": "sustain"}
	instance.parameters.merge(input, true)
	return instance
