shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled, unshaded;
uniform float source_alpha = 0.0;
void fragment() {
	// Original StandardMaterial3D unshaded source scalar/alpha, before finishing.
	ALBEDO = vec3(0.88);
	ALPHA = source_alpha;
}
