shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled;
uniform sampler2D native_leaf : source_color, filter_linear;
uniform vec4 leaf_colour : source_color;
uniform float presence = 1.;
uniform float cue_opacity = 1.;
void fragment() {
	vec4 original_leaf = texture(native_leaf, UV);
	ALBEDO = leaf_colour.rgb * (.55 + original_leaf.r * .45);
	EMISSION = leaf_colour.rgb * .08;
	ALPHA = original_leaf.a * presence * cue_opacity;
}
