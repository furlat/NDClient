extends "res://assets/vfx/conditions/runtime.gd"

static func make_component(input: Dictionary) -> Node3D:
	var instance: Node3D = load("res://assets/vfx/conditions/condition_banishment_persistent/application.gd").new()
	instance.parameters = {"scene": "res://assets/vfx/conditions/condition_banishment_persistent/prepared.scn", "geometry": [], "emitters": [], "application_seconds": 0.35, "removal_seconds": 0.35, "loop_seconds": 2.0, "sustain_gain": 1.0, "actor_history": {"capture_departure": true, "depth_owner": "renderer", "depth_shader": "res://assets/vfx/shared/resources/bda6d5b000039e4a932a2da57906325cb960203a5955eb6f5b5b0d9510d14dff.res", "mirror": false, "output_material": "res://assets/vfx/shared/resources/6533265b252912b6acddf4d29979a8aa3ff93913c77a7cb5383f9313feb8cb9d.res", "pose_material_cache_limit": 64.0, "required_depth_encoding": "rgb24_reversed_z", "source_shader": "res://assets/vfx/shared/resources/e7ee404afa25f1a82e67ee0e853f083d0e72c1c568063acea0d3b2074d02f6bb.res", "specifications": [{"actor": "recipient", "begin": -1000.0, "delay": 0.08, "end": 1e+30, "id": "banished-echo", "offset": [0.0, 0.0, 0.0], "opacity": 0.13}]}, "phase": "application"}
	instance.parameters.merge(input, true)
	return instance
