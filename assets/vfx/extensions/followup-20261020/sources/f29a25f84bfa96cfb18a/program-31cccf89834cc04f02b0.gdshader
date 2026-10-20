shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform bool Fresnel_Invert = false;
uniform float Fresnel_Power = 1.0;
uniform sampler2D Gradient_1D_Color : source_color, repeat_disable;
uniform float Vanishing : hint_range(0.0, 1.0) = 1.0;



void fragment() {
// BooleanParameter:4
	bool n_out4p0 = Fresnel_Invert;


// FloatParameter:3
	float n_out3p0 = Fresnel_Power;


// Fresnel:2
	float n_out2p0 = n_out4p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out3p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out3p0));


	vec4 n_out8p0;
// Texture2D:8
	n_out8p0 = texture(Gradient_1D_Color, vec2(n_out2p0));
	float n_out8p4 = n_out8p0.a;


// Input:5
	vec4 n_out5p0 = COLOR;
	float n_out5p4 = n_out5p0.a;


// VectorOp:9
	vec3 n_out9p0 = vec3(n_out8p0.xyz) * vec3(n_out5p0.xyz);


// FloatOp:6
	float n_out6p0 = n_out8p4 * n_out5p4;


// FloatParameter:11
	float n_out11p0 = Vanishing;


// FloatOp:10
	float n_out10p0 = n_out6p0 * n_out11p0;


// Output:0
	ALBEDO = n_out9p0;
	ALPHA = n_out10p0;


}


