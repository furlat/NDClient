shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform sampler2D tex : source_color;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_mult : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float emission : hint_range(0.0, 12.0, 0.05) = 4.0;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		vec3 c = MODEL_MATRIX[3].xyz;
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(INV_VIEW_MATRIX[0].xyz * sx, 0.0),
			vec4(INV_VIEW_MATRIX[1].xyz * sy, 0.0),
			vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
			vec4(c, 1.0));
	}
}

void fragment() {
	float m = texture(tex, UV).r;
	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission * m;
	ALPHA = clamp(m * alpha_mult, 0.0, 1.0);
}

