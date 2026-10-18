extends RefCounted
## Fade only the oldest trail tail. Continuation ribbons use longitudinal UV=1.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")


static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	assert(specification.profile == "oldest_history_smoothstep")
	var fraction := float(specification.fraction)
	assert(fraction > 0.0 and fraction <= 0.5)
	var code: String = material.shader.code
	assert(code.contains("source_alpha *= coverage;") and not code.contains("guardian_blade_tail_fraction"))
	code = code.replace("void fragment() {", "uniform float guardian_blade_tail_fraction = 0.25;\nvoid fragment() {")
	code = code.replace("source_alpha *= coverage;", "source_alpha *= coverage;\n\tsource_alpha *= smoothstep(0.0, guardian_blade_tail_fraction, clamp(UV.y, 0.0, 1.0));")
	var shader := Shader.new()
	shader.code = code
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("guardian_blade_tail_fraction", fraction)
