extends RefCounted
## Response-local coverage derivative; frozen source-energy shader stays intact.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const ALPHA_LINE := "float source_alpha = clamp(COLOR.a, 0.0, 1.0);"
const COVERAGE := """
	float across = clamp(UV.x, 0.0, 1.0);
	float coverage = smoothstep(0.0, guardian_blade_cross_feather, across)
		* (1.0 - smoothstep(1.0 - guardian_blade_cross_feather, 1.0, across));
	source_alpha *= coverage;
"""


static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	assert(specification.profile == "bounded_cross_width_smoothstep")
	var feather := float(specification.fraction)
	assert(feather > 0.0 and feather <= 0.5)
	var original: Shader = material.shader
	assert(original.code.contains(ALPHA_LINE) and original.code.contains("cie_linear_channel(encoded_energy.r)"))
	assert(not original.code.contains("guardian_blade_cross_feather"))
	var shader := Shader.new()
	shader.code = original.code.replace("void fragment() {", "uniform float guardian_blade_cross_feather = 0.25;\nvoid fragment() {")
	shader.code = shader.code.replace(ALPHA_LINE, ALPHA_LINE + COVERAGE)
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("guardian_blade_cross_feather", feather)
