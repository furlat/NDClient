shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, ambient_light_disabled, shadow_to_opacity, fog_disabled;

uniform float Size_Sphere = 0.0;
uniform sampler2D Hit_Texture : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_Color_1D : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_Dissapear : source_color, filter_linear, repeat_disable;



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:3
	vec3 n_out3p0 = NORMAL;


// FloatParameter:6
	float n_out6p0 = Size_Sphere;


// VectorOp:5
	vec3 n_out5p0 = n_out3p0 * vec3(n_out6p0);


// VectorOp:4
	vec3 n_out4p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out4p0;


}

void fragment() {
// Input:12
	vec4 n_out12p0 = COLOR;
	float n_out12p4 = n_out12p0.a;


// VectorCompose:8
	float n_in8p0 = 0.00000;
	vec2 n_out8p0 = vec2(n_in8p0, n_out12p4);


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out8p0 * n_in6p1 + UV;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Hit_Texture, n_out6p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out5p0;
// Texture2D:5
	n_out5p0 = texture(Gradient_Color_1D, vec2(n_out3p1));


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Gradient_Dissapear, UV);
	float n_out10p1 = n_out10p0.r;


// FloatOp:11
	float n_out11p0 = n_out3p1 * n_out10p1;


// Output:0
	ALBEDO = vec3(n_out5p0.xyz);
	ALPHA = n_out11p0;


}


