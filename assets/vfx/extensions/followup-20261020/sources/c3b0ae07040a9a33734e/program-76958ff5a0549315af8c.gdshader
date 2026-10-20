shader_type spatial;
uniform float vfx_clock=0.0;
uniform float vfx_alpha=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Texture : source_color, filter_linear, repeat_disable;



void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture, UV);
	float n_out3p1 = n_out3p0.r;


// FloatOp:5
	float n_out5p0 = n_out4p4 * n_out3p1;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out5p0;



ALPHA *= vfx_alpha;
}


