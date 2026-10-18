shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Texture : source_color, repeat_disable;
uniform float Black_Threshold = 0.08;
uniform float Softness = 0.12;
uniform float Alpha_Multiplier = 1.0;

void fragment() {
	vec4 tex = texture(Texture, UV);
	float brightness = max(max(tex.r, tex.g), tex.b);
	float mask = smoothstep(Black_Threshold, Black_Threshold + Softness, brightness);
	vec3 color = tex.rgb * COLOR.rgb;
	ALBEDO = color;
	EMISSION = color;
	ALPHA = tex.a * COLOR.a * mask * Alpha_Multiplier;
}
