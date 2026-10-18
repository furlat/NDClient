shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform vec4 color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float emission : hint_range(0.0, 8.0, 0.05) = 1.5;
uniform float alpha_mult : hint_range(0.0, 2.0, 0.01) = 1.0;

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
	float soft = pow(clamp(1.0 - cu, 0.0, 1.0), 1.8);
	float ends = smoothstep(0.0, 0.05, v_uv.y) * smoothstep(1.0, 0.82, v_uv.y);
	vec3 col = color.rgb * soft;
	ALBEDO = col;
	EMISSION = col * emission;
	ALPHA = clamp(soft * alpha_mult, 0.0, 1.0) * ends;
}
