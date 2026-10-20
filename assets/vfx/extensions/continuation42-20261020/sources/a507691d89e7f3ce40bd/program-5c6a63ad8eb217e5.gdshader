shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float factory_occurrence_alpha=1.0;

uniform float receive_layer_alpha=1.0;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_noise : source_color, repeat_enable;
uniform sampler2D Texture_add : source_color, hint_default_black, repeat_enable;
uniform sampler2D Texture_substract : source_color, hint_default_black, repeat_enable;
uniform sampler2D Gradient_Color_1D : source_color, repeat_disable;
uniform float Color_Intensity = 1.0;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;



void fragment() {
// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:11
	vec2 n_out11p0 = Speed_XY;


// Input:10
	float n_out10p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// VectorOp:12
	vec2 n_out12p0 = n_out11p0 * vec2(n_out10p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out12p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_noise, n_out8p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out5p0;
// Texture2D:5
	n_out5p0 = texture(Texture_add, UV);
	float n_out5p1 = n_out5p0.r;


// FloatOp:14
	float n_out14p0 = n_out3p1 + n_out5p1;


	vec4 n_out6p0;
// Texture2D:6
	n_out6p0 = texture(Texture_substract, UV);
	float n_out6p1 = n_out6p0.r;


// FloatOp:15
	float n_out15p0 = n_out14p0 - n_out6p1;


// Clamp:16
	float n_in16p1 = 0.00000;
	float n_in16p2 = 1.00000;
	float n_out16p0 = clamp(n_out15p0, n_in16p1, n_in16p2);


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Gradient_Color_1D, vec2(n_out16p0));
	float n_out18p4 = n_out18p0.a;


// FloatParameter:20
	float n_out20p0 = Color_Intensity;


// VectorOp:19
	vec3 n_out19p0 = vec3(n_out18p0.xyz) * vec3(n_out20p0);


// FloatParameter:23
	float n_out23p0 = Opacity;


// FloatOp:22
	float n_out22p0 = n_out18p4 * n_out23p0;


// Output:0
	ALBEDO = n_out19p0;
	ALPHA = n_out22p0;



ALPHA *= support_envelope;

ALPHA *= receive_layer_alpha;

ALPHA *= factory_occurrence_alpha;
}



