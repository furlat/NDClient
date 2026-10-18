extends RefCounted
## Accepted image-hook energy-index response, applied to each live material.
## The original chose a covered sample per 2x2 raster block. This derivative
## retains its exact byte-energy/index law without claiming that raster parity.
const Sources = preload("res://assets/vfx/sources/39ced3e79a9833e731fb/source_materials.gd")
const Stage = preload("res://assets/vfx/sources/7ffdb77f06cb06b0c42e/contract_stage.gd")
const CIE := "res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc"
const UNIFORMS := """
uniform sampler2D item_source_finish_palette:filter_nearest,repeat_disable;
uniform int item_source_finish_count=6;
uniform float item_source_finish_exponent=1.15;
"""
const RESPONSE := """
	// Exact accepted energy-index threshold, after the unchanged source alpha.
	// No Reinhard transform, guessed tint, alpha rewrite or added emission.
	// Original raw RGB was linear-premultiplied. Read its existing coverage;
	// never divide by alpha or rewrite the source alpha/owner envelope.
	vec3 item_source_raw = ALBEDO * clamp(ALPHA, 0.0, 1.0);
	vec3 item_source_encoded = vec3(cie_encoded_channel(item_source_raw.r), cie_encoded_channel(item_source_raw.g), cie_encoded_channel(item_source_raw.b));
	float item_source_energy = clamp(max(max(item_source_encoded.r, item_source_encoded.g), item_source_encoded.b), 0.0, 1.0);
	float item_source_byte = floor(item_source_energy * 255.0 + 0.5);
	int item_source_index = int(floor(pow(item_source_byte / 255.0, item_source_finish_exponent) * float(item_source_finish_count - 1) + 0.5));
	item_source_index = clamp(item_source_index, 0, item_source_finish_count - 1);
	vec3 item_source_stop = texture(item_source_finish_palette, vec2((float(item_source_index) + 0.5) / float(item_source_finish_count), 0.5)).rgb;
	// CIE matches the already selected exact source stop. It does not replace
	// the original index threshold with a different nearest-ramp decision.
	vec3 item_source_choice = cie_nearest(item_source_stop, item_source_finish_palette, item_source_finish_count, 0.0, 0.0);
	ALBEDO = vec3(cie_linear_channel(item_source_choice.r), cie_linear_channel(item_source_choice.g), cie_linear_channel(item_source_choice.b));
"""


static func header() -> String:
	return "\n" + VfxPackageIO_ac0498530f.text(CIE) + UNIFORMS


static func apply(material: ShaderMaterial, descriptor: Dictionary) -> void:
	assert(descriptor.kind == "accepted_covered_sample_energy_index_native_derivative")
	assert(descriptor.source_encoding == "forward_plus_linear_albedo")
	assert(descriptor.colors.size() == 6 and float(descriptor.exponent) == 1.15)
	assert(not descriptor.historical_raster_parity)
	assert(not material.has_meta("item_source_energy_finish"))
	var original: String = material.shader.code
	assert(original.contains("float calm_energy=") and original.contains("ALBEDO=vec3(clamp(calm_energy*0.32,0.22,0.72));"))
	assert(not original.contains("EMISSION"), "This source's original response is ALBEDO only")
	var shader := Shader.new()
	shader.code = Sources.finish_fragment(original, RESPONSE).replace("shader_type spatial;", "shader_type spatial;" + header())
	Sources.replace_shader(material, shader)
	material.set_shader_parameter("item_source_finish_palette", Stage.palette_texture(descriptor.colors))
	material.set_shader_parameter("item_source_finish_count", descriptor.colors.size())
	material.set_shader_parameter("item_source_finish_exponent", float(descriptor.exponent))
	material.set_meta("item_source_energy_finish", true)
	material.set_meta("historical_post_raster_parity", false)


static func recover_original(code: String) -> String:
	return code.replace(RESPONSE, "").replace("shader_type spatial;" + header(), "shader_type spatial;")


static func source_index(encoded_energy: float, descriptor: Dictionary) -> int:
	var byte := roundf(clampf(encoded_energy, 0.0, 1.0) * 255.0)
	return clampi(int(roundf(pow(byte / 255.0, float(descriptor.exponent)) * float(descriptor.colors.size() - 1))), 0, descriptor.colors.size() - 1)


static func encoded_stop(encoded_energy: float, descriptor: Dictionary) -> Color:
	return Color(str(descriptor.colors[source_index(encoded_energy, descriptor)]))

const VfxPackageIO_ac0498530f = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
