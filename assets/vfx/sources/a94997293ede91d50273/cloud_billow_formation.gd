extends "res://assets/vfx/sources/b7e4f5e433685cdff4bb/cloud_cohorts.gd"
## Birth admits whole source billows instead of slicing a travelling wall
## through their camera-facing cards. Held geometry and cohort retirement stay.


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/a94997293ede91d50273/cloud_billow_formation.gd", input)


func apply_scene_edits(node: Node) -> void:
	super.apply_scene_edits(node)
	for material in mats:
		var code: String = material.shader.code
		var begin: int = code.find("float arrival=radial/cloud_radius")
		var end: int = code.find("alpha*=smoothstep(-.06,.18,cloud_world.y)", begin)
		assert(begin >= 0 and end > begin, "Cloud source birth predicate changed")
		code = code.substr(0, begin) + "float spread=smoothstep(cloud_billow_arrival,cloud_billow_arrival+.32,cloud_age/1.05);\n " + code.substr(end)
		code = code.replace("shader_type spatial;", "shader_type spatial;\nvarying flat float cloud_billow_arrival;")
		code = SourceMaterials.finish_function(code, "vertex", "\nvec3 billow_center=MODEL_MATRIX[3].xyz;\nfloat billow_distance=length(vec3(billow_center.x,max(0.0,billow_center.y)*.60,billow_center.z));\nfloat billow_seed=fract(sin(float(INSTANCE_ID)*18.317+31.7)*43758.5453);\ncloud_billow_arrival=.65*billow_distance/cloud_radius+.14*billow_seed;\n")
		var macro_weight: float = float(parameters.get("macro_mix", 0.0))
		if macro_weight > 0.0:
			code = SourceMaterials.finish_fragment(code, "\nfloat cloud_macro=loop_texture(mask2_texture,cloud_world.xz*.12+vec2(.17,0.0),vec2(.009,-.007)).r;\nALBEDO*=mix(1.0,mix(.65,1.08,smoothstep(.24,.70,cloud_macro)),%s);\n" % macro_weight)
		var shader := Shader.new()
		shader.code = code
		SourceMaterials.replace_shader(material, shader)
