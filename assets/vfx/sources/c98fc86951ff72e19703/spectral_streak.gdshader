shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// The original authored prism source's two-scale moving noise is retained;
// geometry, seven-rule-color mapping and finite stroke envelope are distinct.
uniform sampler2D authored_noise : repeat_enable, filter_linear;
uniform vec4 ray_color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform vec4 ray_shadow : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float source_seconds = 0.0;
uniform float ray_index = 0.0;
uniform float opacity = 0.0;

void fragment() {
	float flowing = texture(authored_noise, vec2(UV.x * 4.0 + ray_index * 0.22, UV.y * 1.4 - source_seconds * 1.6)).r;
	float fine = texture(authored_noise, vec2(UV.x * 19.0 + ray_index * 0.1, UV.y * 0.6 - source_seconds * 2.4)).r;
	float edges = smoothstep(0.0, 0.22, UV.x) * (1.0 - smoothstep(0.78, 1.0, UV.x));
	float tip = 1.0 - smoothstep(0.9, 1.0, UV.y);
	ALBEDO = mix(ray_shadow.rgb, ray_color.rgb, 0.25 + 0.75 * flowing);
	ALPHA = ray_color.a * opacity * edges * tip * (0.25 + 0.75 * smoothstep(0.18, 0.55, flowing)) * (0.6 + 0.4 * smoothstep(0.18, 0.42, fine));
}
