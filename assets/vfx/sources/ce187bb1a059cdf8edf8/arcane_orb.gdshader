shader_type spatial;
render_mode blend_add, cull_back, unshaded, depth_draw_never, shadows_disabled;

uniform vec4 orb_color : source_color = vec4(0.16, 0.42, 0.95, 1.0);
uniform vec4 rim_color : source_color = vec4(0.5, 0.82, 1.0, 1.0);
uniform sampler2D noise_texture;
uniform float intensity : hint_range(0.0, 3.0, 0.05) = 0.95;
uniform float fresnel_power : hint_range(0.5, 8.0, 0.1) = 3.4;
uniform float core_alpha : hint_range(0.0, 1.0, 0.01) = 0.03;
uniform float core_gain : hint_range(0.0, 2.0, 0.05) = 0.0;
uniform float pulse_speed : hint_range(0.0, 6.0, 0.05) = 1.57;

vec2 sphere_uv(vec3 n) {
	return vec2(atan(n.z, n.x) / TAU + 0.5, asin(clamp(n.y, -1.0, 1.0)) / PI + 0.5);
}

void fragment() {
	vec3 nrm = normalize(NORMAL);
	float ndv = clamp(dot(nrm, normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, fresnel_power);
	float core = pow(ndv, 2.5) * core_gain;
	float n = texture(noise_texture, sphere_uv(nrm) * 1.6 + TIME * vec2(0.03, 0.05)).r;
	float breath = 0.92 + 0.08 * sin(TIME * pulse_speed);

	vec3 col = orb_color.rgb * (0.35 + core) + rim_color.rgb * fres + rim_color.rgb * n * 0.14;
	ALBEDO = col * intensity * breath;
	ALPHA = clamp(core_alpha + fres * 0.6 + core * 0.35 + n * 0.06, 0.0, 0.92);
}
