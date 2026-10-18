shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform float spell_clock=0.0;
uniform sampler2D noise_tex : repeat_enable;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.72, 0.26, 1.0);
uniform float intensity : hint_range(0.0, 5.0, 0.05) = 2.0;
uniform float top_fade : hint_range(0.1, 1.0, 0.01) = 0.9;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec2 v_uv;
varying vec3 v_w;

void vertex() {
	v_uv = UV;
	v_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(vec3(cam_right.x, 0.0, cam_right.z));
	vec3 fwd = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float yb = clamp(v_uv.y, 0.0, 1.0);
	float shimmer = texture(noise_tex, v_uv * vec2(2.4, 2.2) + vec2(v_w.x * 0.3, -spell_clock * 0.65)).r;
	float curl = texture(noise_tex, vec2(v_uv.y * 1.8 - spell_clock * .3, v_w.x + spell_clock * .17)).r;
	float centre = .5 + (curl - .5) * .28 * sin(yb * 3.14159);
	float xc = abs(v_uv.x - centre) * 2.0;
	// Both ends taper well inside the quad. Noise sculpts the crest, never reveals its edge.
	float width = .72 * pow(max(0.0, sin(yb * 3.14159)), .8);
	float beam = pow(1.0 - smoothstep(width * .15, max(.001,width), xc), 1.6);
	float crest = .12 + .21 * texture(noise_tex, vec2(v_uv.x * 2.1, spell_clock * .23)).r;
	float vert = smoothstep(crest, crest + .23, yb) * (1.0 - smoothstep(.62, .96, yb));
	vec3 col = mix(edge_color.rgb, core_color.rgb, beam * .8);
	float a = beam * vert * smoothstep(.27,.67,shimmer);

	ALBEDO = col;
	EMISSION = col * intensity * .12;
	ALPHA = clamp(a, 0.0, 1.0) * alpha_mult;
}
