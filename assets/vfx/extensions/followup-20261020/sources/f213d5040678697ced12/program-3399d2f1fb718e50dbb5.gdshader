shader_type spatial;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Texture : source_color, filter_linear;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
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
	ALPHA = min(1.0, n_out4p0 * 2.2);


}



