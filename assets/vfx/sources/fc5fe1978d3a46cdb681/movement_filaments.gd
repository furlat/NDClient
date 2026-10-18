extends "res://assets/vfx/sources/dbbd11d7b37fd1be2bc0/movement.gd"
## Preserve the moving wind source; recover local variation inside its bands.
const FilamentBindings = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/fc5fe1978d3a46cdb681/movement_filaments.gd", input)


func adapt(material: ShaderMaterial) -> void:
	super.adapt(material)
	if settings.name != "VFX_WindAura_1" or material != haste_mesh.material_override:
		return
	var original := "ALBEDO = n_out19p0;"
	var code: String = material.shader.code
	assert(code.count(original) == 1, "Wind source colour output changed")
	# Integer UV multiples retain the original two-second panning period.
	# The original spiral texture owns breakup; no new geometric carrier.
	var replacement := """
	float filament = texture(Base_noise, n_out8p0 * vec2(1.0, 2.0) + vec2(0.0, 0.23)).r;
	float flow_density = smoothstep(0.10, 0.80, filament);
	ALBEDO = n_out19p0 * mix(0.32, 0.88, flow_density);
	"""
	code = code.replace(original, replacement)
	var alpha := "ALPHA = n_out27p0 * smoothstep(0.02,0.18,UV.y) * (1.0-smoothstep(0.78,0.98,UV.y));"
	assert(code.count(alpha) == 1, "Wind source alpha output changed")
	code = code.replace(alpha, alpha + "\nALPHA *= mix(0.08, 0.80, flow_density);\n")
	var shader := Shader.new()
	shader.code = code
	FilamentBindings.replace_shader(material, shader)
