shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
#include "res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc"

// This family's old SCREEN coefficients weight encoded source RGB. Forward+
// ADD weights linear ALBEDO by ALPHA, so undo only that ordering difference.
// Vertex alpha already contains the qualified occurrence envelope once.
void fragment() {
	float source_alpha = clamp(COLOR.a, 0.0, 1.0);
	vec3 source_encoded = clamp(COLOR.rgb, vec3(0.0), vec3(1.0));
	vec3 encoded_energy = source_encoded * source_alpha;
	if (OUTPUT_IS_SRGB) {
		ALBEDO = source_encoded;
	} else if (source_alpha > 0.0) {
		ALBEDO = vec3(cie_linear_channel(encoded_energy.r), cie_linear_channel(encoded_energy.g), cie_linear_channel(encoded_energy.b)) / source_alpha;
	} else {
		ALBEDO = vec3(0.0);
	}
	ALPHA = source_alpha;
}
