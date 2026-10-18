shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(0.32, 0.7, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(0.85, 0.96, 1.0, 1.0);
uniform sampler2D rune_texture : repeat_enable;
uniform float intensity : hint_range(0.0, 5.0, 0.05) = 2.2;
uniform float tile : hint_range(0.5, 8.0, 0.5) = 1.0;
uniform float scroll_speed : hint_range(-2.0, 2.0, 0.005) = 0.125;
uniform float pulse_speed : hint_range(0.0, 6.0, 0.05) = 1.57;
uniform float pulse_depth : hint_range(0.0, 0.6, 0.01) = 0.12;
uniform float hot_threshold : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float flow_speed : hint_range(0.0, 2.0, 0.005) = 0.25;
uniform float flow_gain : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float back_dim : hint_range(0.0, 1.0, 0.01) = 0.62;
uniform float phase = 0.0;

void fragment() {
	float u = fract(UV.x * tile + TIME * scroll_speed + phase);
	float tex = texture(rune_texture, vec2(u, UV.y)).r;

	float center = fract(TIME * flow_speed + phase * 0.5);
	float du = abs(fract(UV.x - center + 0.5) - 0.5);
	float flow = exp(-du * du / (2.0 * 0.022 * 0.022));

	float hot = smoothstep(hot_threshold, 1.0, tex);
	vec3 col = mix(ring_color.rgb, hot_color.rgb, hot);
	col += hot_color.rgb * flow * tex * flow_gain;

	float face = dot(normalize(NORMAL), normalize(VIEW));
	float depth = mix(back_dim, 1.0, smoothstep(-0.4, 0.4, face));

	float pulse = (1.0 - pulse_depth) + pulse_depth * sin(TIME * pulse_speed + phase * 6.2831853);
	ALBEDO = col * intensity * pulse * depth;
	ALPHA = clamp(tex * (0.8 + flow * 0.6) * depth, 0.0, 1.0);
}
