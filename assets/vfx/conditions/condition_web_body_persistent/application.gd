extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_web_body_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_web_body_persistent/prepared.scn", "geometry": ["assembly/am_web_trap/WebArmature/Skeleton3D/webs_low", "assembly/UpperBodySilkPatch0", "assembly/UpperBodySilkPatch1", "assembly/UpperBodySilkPatch2", "assembly/UpperBodySilkPatch3"], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "adaptive_surface": {"kind": "web_body", "settings": {"clearance_cells": 0.04, "lower_path": "assembly/am_web_trap", "source_bounds": [-1.18076491355896, -0.0142939276993275, -1.18156766891479, 2.36110186576843, 1.03403830528259, 2.36323213577271]}}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
