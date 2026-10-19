extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_shillelagh_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_shillelagh_persistent/prepared.scn", "geometry": ["interval/ActualEquippedItemEnchantment"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "measured", "settings": {"clearance_cells": 0.008, "nodes": ["ActualEquippedItemEnchantment"], "requires_equipped_item": true, "slot": "weapon"}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
