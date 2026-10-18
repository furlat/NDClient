extends RefCounted
## Explicit compatibility for the archived guardian's unshaded shader literals.
## Both source renderers ignore EMISSION in unshaded output. Keep its original
## equation, the source ALPHA, and all geometry/normal/rim/flow math intact.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const CAPTURE_ENCODING := "gl_compatibility_unshaded_albedo"
const DECLARATIONS := """
#include "res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc"
uniform bool guardian_source_encoded_albedo = false;
"""
const OUTPUT_ADAPTER := """
	// Explicit source-family transfer; Compatibility already performs this decode.
	if (guardian_source_encoded_albedo && !OUTPUT_IS_SRGB) {
		ALBEDO = vec3(cie_linear_channel(ALBEDO.r), cie_linear_channel(ALBEDO.g), cie_linear_channel(ALBEDO.b));
	}
"""


static func apply(material: ShaderMaterial, specification: Dictionary) -> void:
	assert(specification.get("capture_encoding", "") == CAPTURE_ENCODING,
		"Guardian compatibility requires its verified original capture encoding")
	assert(material != null and material.shader != null)
	var original: Shader = material.shader
	assert(original.code.contains("render_mode unshaded,cull_disabled;"))
	assert(not original.code.contains("guardian_source_encoded_albedo"))
	var shader := Shader.new()
	var code: String = original.code.replace("shader_type spatial;", "shader_type spatial;" + DECLARATIONS)
	shader.code = Sources.finish_fragment(code, OUTPUT_ADAPTER)
	shader.set_meta("factory_guardian_original_shader", original)
	shader.set_meta("factory_guardian_capture_encoding", CAPTURE_ENCODING)
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("guardian_source_encoded_albedo", true)
