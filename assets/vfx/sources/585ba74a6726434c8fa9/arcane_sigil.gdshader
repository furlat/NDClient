shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(0.32, 0.7, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.85, 0.96, 1.0, 1.0);
uniform sampler2D circle_texture;
uniform float intensity : hint_range(0.0, 5.0, 0.05) = 2.0;
uniform float spin_speed : hint_range(-3.0, 3.0, 0.01) = 0.39;
uniform float pulse_speed : hint_range(0.0, 6.0, 0.05) = 1.57;
uniform float pulse_depth : hint_range(0.0, 0.6, 0.01) = 0.16;
uniform float hot_threshold : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float inner_fade : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float a = TIME * spin_speed;
	float c = cos(a);
	float s = sin(a);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c) + vec2(0.5);
	float tex = texture(circle_texture, uv).r;

	float r = length(UV - vec2(0.5)) * 2.0;
	float fade = (1.0 - smoothstep(0.9, 1.0, r)) * smoothstep(inner_fade, inner_fade + 0.12, r);
	float pulse = (1.0 - pulse_depth) + pulse_depth * sin(TIME * pulse_speed);

	vec3 col = mix(ring_color.rgb, hot_color.rgb, smoothstep(hot_threshold, 1.0, tex));
	ALBEDO = col * intensity * pulse;
	ALPHA = clamp(tex * fade, 0.0, 1.0);
}
