extends "res://assets/vfx/sources/4e574280934fd6f428a0/elemental_shield.gd"
## Native shield texture, with quiet surface coverage and complete world geometry.
const SourceMaterials = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/a0c9b57365844320e9a9/elemental_shield_readable.gd", input)


func adapt(material: ShaderMaterial, cold: bool) -> void:
	super.adapt(material, cold)
	var code: String = material.shader.code
	# The old split is an export-camera plane in absolute source coordinates.
	# A live occurrence must retain its own complete source geometry.
	var split_start: int = code.find("vec3 wp=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;")
	assert(split_start >= 0)
	var split_end: int = code.find(")discard;", split_start) + ")discard;".length()
	assert(split_end > split_start)
	code = code.left(split_start) + code.substr(split_end)
	code = code.replace("if(wp.x<.18 || abs(wp.z)>.50)discard;", "")
	if not parameters.kind.ends_with("contact") and not parameters.kind.ends_with("reaction"):
		# Preserve the actual two source colour gradients instead of flattening
		# their output into one saturated value. Native noise/fresnel also govern
		# coverage, leaving the real actor readable through a sustained surface.
		var old_tint: String = (
			"float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.025,.14,.35),vec3(.20,.57,.82),clamp(v,0.,1.));"
			if cold
			else "float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.48,.025,.003),vec3(.98,.28,.012),clamp(v,0.,1.));"
		)
		assert(code.contains(old_tint))
		code = code.replace(old_tint, "")
		code = SourceMaterials.finish_fragment(code, "\nfloat source_coverage=mix(0.10,0.42,smoothstep(0.10,0.65,n_out41p1));\nALPHA*=source_coverage*mix(0.35,1.0,clamp(n_out11p0,0.0,1.0));\nALBEDO/=1.0+0.30*max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));\n")
	else:
		# Contact remains an energetic finite source, with no export-only slice
		# or artificial threefold alpha amplification over the attacker.
		code = code.replace("ALPHA=min(1.,ALPHA*3.);", "")
	var shader := Shader.new()
	shader.code = code
	SourceMaterials.replace_shader(material, shader)


func capture_observation() -> Dictionary:
	var result: Dictionary = super.capture_observation()
	result["native_shield_readability"] = {
		"complete_original_geometry": true,
		"source_gradients_masks_clocks_retained": true,
		"sustain_coverage": "original noise and fresnel; explicit material alpha",
		"retaliation_export_slice_removed": true,
		"human_approval": false
	}
	return result
