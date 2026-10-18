
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

uniform float Size_Sphere = 0.26;
uniform float Hit_Phase = 1.0;
uniform sampler2D Hit_Texture : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_Color_1D : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_Dissapear : source_color, filter_linear, repeat_disable;
uniform float Color_Gain = 3.0;
uniform float Alpha_Gain = 4.0;

void vertex() {
	VERTEX += NORMAL * Size_Sphere;
}

void fragment() {
	vec2 phase_uv = UV + vec2(0.0, Hit_Phase);
	float hit_value = texture(Hit_Texture, phase_uv).r;
	float fade_value = texture(Gradient_Dissapear, UV).r;
	vec4 color_value = texture(Gradient_Color_1D, vec2(hit_value, 0.0));
	ALBEDO = color_value.rgb * Color_Gain;
	ALPHA = clamp(hit_value * fade_value * Alpha_Gain, 0.0, 1.0);
}
