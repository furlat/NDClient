shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

varying flat vec4 plant_native_state;
render_mode blend_mix, cull_disabled, diffuse_lambert, shadows_disabled;
uniform sampler2D native_leaf : source_color, filter_linear;
uniform vec4 leaf_tint : source_color;
uniform float growth_clock_seconds = 0.;

uniform float cue_opacity = 1.;
void vertex() {
plant_native_state=INSTANCE_CUSTOM;

	// The root stays pinned to the sampled native stem. Only the outer leaf
	// bends, retaining a substantial cambered 3D silhouette while alive.
	float tip = 1. - UV.y;
	VERTEX.z += sin(growth_clock_seconds * 1.4 + VERTEX.y * 6.) * .012 * tip * tip;

mat3 plant_basis=mat3(MODELVIEW_MATRIX);if(determinant(plant_basis)!=0.0){MODELVIEW_NORMAL_MATRIX=transpose(inverse(plant_basis));}
}
void fragment() {
if(plant_native_state.z<.5)discard;

	vec4 leaf = texture(native_leaf, UV);
	ALBEDO = leaf.rgb * leaf_tint.rgb;
	ROUGHNESS = .85;
	ALPHA = leaf.a * plant_native_state.y * cue_opacity;

ALPHA *= factory_occurrence_alpha;
}




