shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.42, 0.52, 1.0, 1.0);
uniform float emission : hint_range(0.0, 12.0, 0.05) = 3.2;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D noise_tex : repeat_enable;
uniform float noise_scale = 3.5;
uniform float noise_scroll = 1.6;

varying vec2 v_uv;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vt = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float tl = length(vt);
	vt = tl > 0.0001 ? vt / tl : vec3(0.0, 1.0, 0.0);
	vec3 viewdir = normalize(-vp.xyz);
	vec3 right = cross(vt, viewdir);
	float rl = length(right);
	right = rl > 0.0001 ? right / rl : vec3(1.0, 0.0, 0.0);
	float side = (UV.x - 0.5) * 2.0;
	vp.xyz += right * side * COLOR.r;
	v_uv = UV;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float cu = abs(v_uv.x - 0.5) * 2.0;
	float edge = clamp(1.0 - cu, 0.0, 1.0);

	vec2 nuv = vec2(v_uv.x * 0.6, v_uv.y * noise_scale - TIME * noise_scroll);
	float n1 = texture(noise_tex, nuv).r;
	float n2 = texture(noise_tex, nuv * 2.3 + vec2(0.37, -TIME * noise_scroll * 1.9)).r;
	float flow = 0.55 + 0.9 * mix(n1, n2, 0.5);

	float halo = pow(edge, 1.1);
	float core = pow(edge, 2.4) * (0.7 + 0.55 * flow);
	float hot = pow(edge, 4.6) * (0.45 + 1.25 * flow);
	float ends = smoothstep(0.0, 0.05, v_uv.y) * smoothstep(1.0, 0.85, v_uv.y);

	vec3 col = glow_color.rgb * halo;
	col += mix(core_color.rgb, vec3(1.0), 0.6) * core;
	col += vec3(1.0) * hot * 1.7;
	float a = max(halo * 0.42, core) * ends;

	ALBEDO = col;
	EMISSION = col * emission * (0.45 + core * 2.8);
	ALPHA = clamp(a, 0.0, 1.0) * alpha_mult;
}
