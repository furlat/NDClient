shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform sampler2D Texture : source_color, repeat_disable;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out15p0);
	float n_out10p1 = n_out10p0.r;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out10p1;
	ALPHA_SCISSOR_THRESHOLD = n_out4p4;



ALPHA *= support_envelope;
}




