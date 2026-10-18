shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D native_streak : source_color, filter_linear, repeat_disable;
uniform float field_opacity = 0.0;
void fragment() {
	float streak = texture(native_streak, UV).r;
	float taper = sin(UV.x*3.14159265)*sin(UV.y*3.14159265);
	ALBEDO = vec3(.25,.48,.65);
	ALPHA = streak*taper*field_opacity*.3;
}
