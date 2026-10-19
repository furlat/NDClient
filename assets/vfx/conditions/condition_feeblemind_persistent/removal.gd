extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_feeblemind_persistent/removal.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_feeblemind_persistent/prepared.scn", "geometry": ["receiving/ReceivingForm0Layer0", "receiving/ReceivingForm1Layer0", "receiving/ReceivingForm0Layer1", "receiving/ReceivingForm1Layer1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 25.1327412287183, "sustain_gain": 1.0, "adaptive_surface": {"kind": "forms", "settings": {"height_cap_cells": 0.12, "readable": true, "width_cap_cells": 0.17}}, "phase": "removal"}
	instance.parameters.merge(input, true)
	return instance
