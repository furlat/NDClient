shader_type spatial;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform vec4 Color : source_color;
uniform float Fresnel = 8.0;
uniform float Blinking_speed = 0.0;



void fragment() {
// ColorParameter:3
	vec4 n_out3p0 = Color;


// FloatParameter:4
	float n_out4p0 = Fresnel;


// Fresnel:2
	float n_out2p0 = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out4p0);


// Input:5
	float n_out5p0 = source_clock;


// FloatParameter:7
	float n_out7p0 = Blinking_speed;


// FloatOp:6
	float n_out6p0 = n_out5p0 * n_out7p0;


// FloatFunc:9
	float n_out9p0 = cos(n_out6p0);


	float n_out10p0;
// Remap:10
	float n_in10p1 = -1.00000;
	float n_in10p2 = 1.00000;
	float n_in10p3 = 0.00000;
	float n_in10p4 = 1.00000;
	{
		float __input_range = n_in10p2 - n_in10p1;
		float __output_range = n_in10p4 - n_in10p3;
		n_out10p0 = n_in10p3 + __output_range * ((n_out9p0 - n_in10p1) / __input_range);
	}


// FloatOp:11
	float n_out11p0 = n_out2p0 * n_out10p0;


// Output:0
	ALBEDO = vec3(n_out3p0.xyz);
	ALPHA = n_out11p0;


}



