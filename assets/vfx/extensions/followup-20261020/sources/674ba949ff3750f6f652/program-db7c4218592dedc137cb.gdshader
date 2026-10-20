shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Texture : source_color, filter_linear;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:5
	vec4 n_out5p0 = COLOR;
	float n_out5p4 = n_out5p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture, UV);


// SmoothStep:4
	float n_in4p1 = 1.00000;
	float n_out4p0 = smoothstep(n_out5p4, n_in4p1, n_out3p0.x);


// Output:0
	ALBEDO = vec3(n_out5p0.xyz);
	ALPHA = n_out4p0;



ALPHA *= support_envelope;
}




