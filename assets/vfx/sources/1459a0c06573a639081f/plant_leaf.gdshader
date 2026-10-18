shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, shadows_disabled;
uniform sampler2D native_leaf : source_color, filter_linear;
uniform vec4 leaf_tint : source_color;
uniform float growth_clock_seconds = 0.;
uniform float plant_presence = 1.;
uniform float cue_opacity = 1.;
void vertex() {
	// The root stays pinned to the sampled native stem. Only the outer leaf
	// bends, retaining a substantial cambered 3D silhouette while alive.
	float tip = 1. - UV.y;
	VERTEX.z += sin(growth_clock_seconds * 1.4 + VERTEX.y * 6.) * .012 * tip * tip;
}
void fragment() {
	vec4 leaf = texture(native_leaf, UV);
	ALBEDO = leaf.rgb * leaf_tint.rgb;
	ROUGHNESS = .85;
	ALPHA = leaf.a * plant_presence * cue_opacity;
}
