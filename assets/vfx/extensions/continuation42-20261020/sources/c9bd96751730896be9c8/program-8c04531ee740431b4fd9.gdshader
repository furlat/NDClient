shader_type spatial;
uniform float factory_occurrence_alpha=1.0;


uniform vec3 recovery_color_low;
uniform vec3 recovery_color_mid;
uniform vec3 recovery_color_high;
uniform float recovery_levels[8];
uniform float recovery_maximum_byte;
vec3 recovery_decode_srgb(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), encoded));
}

render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled, unshaded;
uniform float source_alpha = 0.0;
void fragment() {
	// Original StandardMaterial3D unshaded source scalar/alpha, before finishing.
	ALBEDO = vec3(0.88);
	ALPHA = source_alpha;

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

ALPHA *= factory_occurrence_alpha;
}


