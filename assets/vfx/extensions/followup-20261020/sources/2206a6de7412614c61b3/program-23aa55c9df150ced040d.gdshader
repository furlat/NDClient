shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float glyph_reveal = 1.0;
uniform vec4 aspect_tint : source_color = vec4(0.47, 0.77, 0.78, 1.0);

// A recipient marker faces the current camera, independently of actor heading.
// Preserve the glyph's world centre and instance scale, including actor scaling.
void vertex() {
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 forward = cross(right, up);
	mat4 facing = mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(forward * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}

void fragment() {

	float motion = 0.5 + 0.5 * sin(UV.x * 29.0 - support_clock * 3.14159265);
	float reveal = 1.0 - smoothstep(glyph_reveal - 0.04, glyph_reveal, UV.x);
	float forming_tip = (1.0 - smoothstep(0.0, 0.12, abs(UV.x - glyph_reveal))) * (1.0 - step(0.99, glyph_reveal));
	ALBEDO = mix(aspect_tint.rgb * (0.65 + 0.35 * motion), vec3(0.88, 0.95, 0.87), forming_tip);
	EMISSION = aspect_tint.rgb * forming_tip * 0.35;
	ALPHA = 0.88 * reveal;

ALPHA *= support_envelope;
}




