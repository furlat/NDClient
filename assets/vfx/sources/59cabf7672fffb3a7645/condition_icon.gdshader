shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Original authored RGBA icon, with no new wobble, palette or shape animation.
uniform sampler2D source_icon : source_color, filter_nearest;
uniform float glyph_clock = 0.0;

void fragment() {
	vec4 icon = texture(source_icon, UV);
	ALBEDO = icon.rgb;
	ALPHA = icon.a;
}
