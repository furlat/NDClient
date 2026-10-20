extends "res://assets/vfx/extensions/followup-20261020/sources/672c1ceae061a45e68c9/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/extensions/followup-20261020/sources/9545d7d5ee4bd6d3129c/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_phantasmal_killer_persistent/prepared.scn", "geometry": ["receiving/ReceivingForm0Layer0", "receiving/ReceivingForm1Layer0", "receiving/ReceivingForm0Layer1", "receiving/ReceivingForm1Layer1"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 19.6349540849362, "sustain_gain": 1.0, "adaptive_surface": {"kind": "forms", "settings": {"height_cap_cells": 0.12, "readable": true, "width_cap_cells": 0.17}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
