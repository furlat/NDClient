shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform sampler2D flow_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(0.85, 0.02, 0.05, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.45, 0.45, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.86, 0.84, 1.0);
uniform float intensity : hint_range(0.0, 8.0, 0.05) = 2.6;
uniform float flow_speed : hint_range(0.0, 4.0, 0.01) = 1.5;
uniform float head_speed : hint_range(0.0, 3.0, 0.01) = 0.55;
uniform float head_sharp : hint_range(2.0, 16.0, 0.1) = 6.5;
uniform float body_alpha : hint_range(0.0, 1.0, 0.01) = 0.46;
uniform float seed = 0.0;
uniform float phase = 0.0;
uniform float charge : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float clock = 0.0;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	vec3 cam_local = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = normalize(cam_local - VERTEX);
	vec3 tang = normalize(NORMAL);
	vec3 side = cross(tang, to_cam);
	float sl = length(side);
	side = sl < 1e-4 ? vec3(0.0, 1.0, 0.0) : side / sl;
	float sgn = UV.y * 2.0 - 1.0;
	VERTEX += side * COLOR.r * sgn;
}

void fragment() {
	float along = v_uv.x;
	float across = v_uv.y;

	float d = clamp(abs(across - 0.5) * 2.0, 0.0, 1.0);
	float soft = exp(-pow(d * 1.7, 2.0));
	float center = pow(1.0 - d, 3.0);

	float ends = smoothstep(0.0, 0.14, along) * (1.0 - smoothstep(0.78, 1.0, along));

	float n1 = texture(flow_tex, vec2(along * 2.1 + seed, across * 0.5 - clock * flow_speed * 0.16 + seed)).r;
	float n2 = texture(flow_tex, vec2(along * 4.6 - clock * flow_speed * 0.5 + seed * 2.0, across * 0.5 + 0.3)).r;
	float wisp = mix(0.62, 1.0, n1) * mix(0.84, 1.0, n2);

	float hp = fract(along - clock * head_speed + phase);
	float head = exp(-pow(hp * head_sharp, 2.0));
	float hp2 = fract(along - clock * head_speed * 0.62 + phase + 0.5);
	head += 0.5 * exp(-pow(hp2 * head_sharp * 1.25, 2.0));
	head = clamp(head, 0.0, 1.0);

	float body_b = body_alpha * soft * wisp;
	float head_b = head * soft * 0.8;
	float bright = body_b + head_b;

	float pink = clamp(center * 0.5 + head * 0.28, 0.0, 1.0);
	vec3 col = mix(base_color.rgb, core_color.rgb, pink);
	float white = clamp(head * (0.35 + 0.7 * center) - 0.32, 0.0, 1.0);
	col = mix(col, hot_color.rgb, white * 0.7);

	float a = bright * ends * alpha_mult;
	float emis = intensity * charge * (0.34 + center * 0.42 + head * (0.4 + 0.5 * center));

	ALBEDO = col;
	EMISSION = col * emis;
	ALPHA = clamp(a, 0.0, 1.0);
}
