shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform vec2 Scale_Water = vec2(1.000000, 1.000000);
uniform vec2 Speed_X_Y = vec2(1.000000, 1.000000);
uniform sampler2D NORMAL_MAP_WATER : hint_normal, filter_linear;
uniform float RefStregnht = 0.01999999955297;
uniform bool Fresnel_Invert;
uniform float Fresnel_power = 1.0;
uniform sampler2D Color_1D_parameter : source_color, repeat_disable, hint_screen_texture;



void fragment() {
// Input:4
	vec2 n_out4p0 = SCREEN_UV;


// Vector2Parameter:23
	vec2 n_out23p0 = Scale_Water;


// UVFunc:22
	vec2 n_in22p2 = vec2(0.00000, 0.00000);
	vec2 n_out22p0 = (UV - n_in22p2) * n_out23p0 + n_in22p2;


// Input:18
	float n_out18p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:20
	vec2 n_out20p0 = Speed_X_Y;


// VectorOp:21
	vec2 n_out21p0 = vec2(n_out18p0) * n_out20p0;


// UVFunc:17
	vec2 n_in17p1 = vec2(1.00000, 1.00000);
	vec2 n_out17p0 = n_out21p0 * n_in17p1 + n_out22p0;


	vec4 n_out25p0;
// Texture2D:25
	n_out25p0 = texture(NORMAL_MAP_WATER, n_out17p0);
	float n_out25p1 = n_out25p0.r;
	float n_out25p2 = n_out25p0.g;


// VectorCompose:3
	vec2 n_out3p0 = vec2(n_out25p1, n_out25p2);


// MultiplyAdd:9
	vec2 n_in9p1 = vec2(2.00000, 2.00000);
	vec2 n_in9p2 = vec2(-1.00000, -1.00000);
	vec2 n_out9p0 = fma(n_out3p0, n_in9p1, n_in9p2);


// FloatParameter:11
	float n_out11p0 = RefStregnht;


// Input:38
	vec4 n_out38p0 = COLOR;
	float n_out38p4 = n_out38p0.a;


// FloatOp:42
	float n_out42p0 = n_out11p0 * n_out38p4;


// VectorOp:10
	vec2 n_out10p0 = n_out9p0 * vec2(n_out42p0);


// VectorOp:5
	vec2 n_out5p0 = n_out4p0 - n_out10p0;


// BooleanParameter:39
	bool n_out39p0 = Fresnel_Invert;


// FloatParameter:32
	float n_out32p0 = Fresnel_power;


// Fresnel:28
	float n_out28p0 = n_out39p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out32p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out32p0));


// Mix:31
	vec2 n_out31p0 = mix(n_out4p0, n_out5p0, n_out28p0);


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Color_1D_parameter, n_out31p0);


// Output:0
	ALBEDO = vec3(n_out35p0.xyz);



ALPHA *= support_envelope;
}


