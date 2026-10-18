extends RefCounted
## Original heal-bank neutral levels and encoded three-stop colorAt. Applying
## them to each native fragment is an explicit live-3D derivative: the archived
## export averaged/unpremultiplied already-rasterized 2x2 blocks before tinting.

const HEADER := """
uniform vec3 recovery_color_low;
uniform vec3 recovery_color_mid;
uniform vec3 recovery_color_high;
uniform float recovery_levels[8];
uniform float recovery_maximum_byte;
vec3 recovery_decode_srgb(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), encoded));
}
"""
const FINISH := """
	// Raw source shader scalar is the Compatibility-encoded value. Do not apply
	// generic Reinhard/CIE finishing or Forward+ encode it before extraction.
	float recovery_byte = clamp(ALBEDO.r, 0.0, 1.0) * 255.0;
	float recovery_neutral = recovery_levels[0];
	float recovery_distance = abs(recovery_byte - recovery_neutral);
	for (int recovery_index = 1; recovery_index < 8; recovery_index++) {
		float candidate_distance = abs(recovery_byte - recovery_levels[recovery_index]);
		if (candidate_distance < recovery_distance) {
			recovery_distance = candidate_distance;
			recovery_neutral = recovery_levels[recovery_index];
		}
	}
	float recovery_position = clamp(recovery_neutral / recovery_maximum_byte, 0.0, 1.0) * 2.0;
	vec3 recovery_encoded = recovery_position < 1.0
		? mix(recovery_color_low, recovery_color_mid, recovery_position)
		: mix(recovery_color_mid, recovery_color_high, recovery_position - 1.0);
	recovery_encoded = floor(recovery_encoded * 255.0 + vec3(0.5)) / 255.0;
	ALBEDO = recovery_decode_srgb(recovery_encoded);
"""


static func apply(material: ShaderMaterial, descriptor: Dictionary) -> void:
	assert(not material.has_meta("accepted_recovery_finish"))
	assert(descriptor.get("kind", "") == "source_scalar_eight_level_three_stop")
	assert(descriptor.get("source_encoding", "") == "gl_compatibility_unshaded")
	assert(descriptor.ramp.size() == 3 and descriptor.neutral_levels.size() == 8)
	var original: String = material.shader.code
	var end := original.rfind("}")
	assert(end > original.find("void fragment"))
	var shader := Shader.new()
	shader.code = original.insert(end, FINISH).replace("shader_type spatial;", "shader_type spatial;\n" + HEADER)
	material.shader = shader
	for index in 3:
		var color := Color(str(descriptor.ramp[index]))
		material.set_shader_parameter(["recovery_color_low", "recovery_color_mid", "recovery_color_high"][index], Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("recovery_levels", PackedFloat32Array(descriptor.neutral_levels))
	material.set_shader_parameter("recovery_maximum_byte", float(descriptor.maximum_byte))
	material.set_meta("accepted_recovery_finish", true)
	material.set_meta("post_raster_export_parity", false)


static func recover_original(code: String) -> String:
	return code.replace(FINISH, "").replace("shader_type spatial;\n" + HEADER, "shader_type spatial;")


static func encoded_color(scalar: float, descriptor: Dictionary) -> Color:
	var nearest: float = float(descriptor.neutral_levels[0])
	for candidate in descriptor.neutral_levels:
		if absf(scalar * 255.0 - float(candidate)) < absf(scalar * 255.0 - nearest):
			nearest = float(candidate)
	var position := clampf(nearest / float(descriptor.maximum_byte), 0.0, 1.0) * 2.0
	var first := mini(1, int(floor(position)))
	var color := Color(str(descriptor.ramp[first])).lerp(Color(str(descriptor.ramp[first + 1])), position - float(first))
	return Color(roundf(color.r * 255.0) / 255.0, roundf(color.g * 255.0) / 255.0, roundf(color.b * 255.0) / 255.0)
