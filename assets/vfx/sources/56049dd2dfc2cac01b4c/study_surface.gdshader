shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.1, 0.3, 0.5, 1.0);
uniform sampler2D source_noise : filter_linear, repeat_enable;
uniform float opacity = 1.0;
uniform float source_seconds = 0.0;
uniform float texture_strength = 0.25;
uniform float edge_softness = 0.18;
uniform float emission_gain = 0.0;

void fragment() {
	float edge = smoothstep(0.0, edge_softness, UV.y) * smoothstep(0.0, edge_softness, 1.0 - UV.y);
	float end = smoothstep(0.0, 0.035, UV.x) * smoothstep(0.0, 0.035, 1.0 - UV.x);
	float fiber = texture(source_noise, UV * vec2(1.7, 0.28) + vec2(source_seconds * 0.045, 0.0)).r;
	ALBEDO = ink_color.rgb * mix(0.72, 1.0, fiber);
	EMISSION = ALBEDO * emission_gain;
	ALPHA = ink_color.a * opacity * edge * end * mix(1.0, smoothstep(0.12, 0.65, fiber), texture_strength);
}
