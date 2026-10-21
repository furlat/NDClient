shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_payload_seconds=0.0;

uniform vec4 payload_source_color=vec4(0.0,0.0,0.0,0.0);
uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Displacement_Speed;
uniform sampler2D Dissplacement_texture : source_color, filter_linear;
uniform sampler2D Dark_Color_Gradient_1D : source_color, filter_linear;
uniform sampler2D Disapear_Noise : source_color, filter_linear;
uniform sampler2D Gradient_1D : source_color, hint_default_black, repeat_disable;
uniform float ProximityFade = 0.5;
uniform sampler2D depth_tex_frg_47 : hint_depth_texture;
uniform sampler2D Emission_Gradient_1D : source_color, filter_linear;
uniform float Hard_Shadow_min = 0.0;
uniform float Hard_Shadow_max = 0.10000000149012;
uniform float Shadow_Min = 0.10000000149012;
uniform float Shadow_Max = 1.0;



void vertex() {
COLOR=payload_source_color;

// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:4
	vec3 n_out4p0 = NORMAL;


// Input:16
	vec4 n_out16p0 = COLOR;
	float n_out16p2 = n_out16p0.g;


// Input:13
	float n_out13p0 = (vfx_package_seconds()+vfx_package_offset_payload_seconds);


// Vector2Parameter:15
	vec2 n_out15p0 = Displacement_Speed;


// VectorOp:14
	vec2 n_out14p0 = vec2(n_out13p0) * n_out15p0;


// UVFunc:12
	vec2 n_in12p1 = vec2(1.00000, 1.00000);
	vec2 n_out12p0 = n_out14p0 * n_in12p1 + UV;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Dissplacement_texture, n_out12p0);
	float n_out11p1 = n_out11p0.r;


// FloatFunc:8
	float n_out8p0 = 1.0 - n_out11p1;


// FloatOp:9
	float n_out9p0 = n_out16p2 * n_out8p0;


// VectorOp:5
	vec3 n_out5p0 = n_out4p0 * vec3(n_out9p0);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
// Input:54
	vec4 n_out54p0 = COLOR;
	float n_out54p1 = n_out54p0.r;


	vec4 n_out45p0;
// Texture2D:45
	n_out45p0 = texture(Dark_Color_Gradient_1D, vec2(n_out54p1));


// Input:33
	vec4 n_out33p0 = COLOR;
	float n_out33p4 = n_out33p0.a;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Disapear_Noise, UV);
	float n_out38p1 = n_out38p0.r;


// SmoothStep:20
	float n_in20p1 = 1.00000;
	float n_out20p0 = smoothstep(min(n_out33p4,0.9999),n_in20p1,n_out38p1);


	vec4 n_out29p0;
// Texture2D:29
	n_out29p0 = texture(Gradient_1D, vec2(n_out20p0));
	float n_out29p1 = n_out29p0.r;


// FloatParameter:48
	float n_out48p0 = ProximityFade;


	float n_out47p0;
// ProximityFade:47
	{
		float __depth_tex = texture(depth_tex_frg_47, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out47p0 = ((isnan(VERTEX.z-__depth_world_pos.z) || isinf(VERTEX.z-__depth_world_pos.z)) ? 1.0 : smoothstep(0.0, max(n_out48p0, 0.0001), VERTEX.z-__depth_world_pos.z));
	}


// FloatOp:46
	float n_out46p0 = n_out29p1 * n_out47p0;


// Input:36
	vec4 n_out36p0 = COLOR;
	float n_out36p1 = n_out36p0.r;


	vec4 n_out50p0;
// Texture2D:50
	n_out50p0 = texture(Emission_Gradient_1D, vec2(n_out36p1));


// Output:0
	ALBEDO = vec3(n_out45p0.xyz);
	ALPHA = n_out46p0;
	EMISSION = vec3(n_out50p0.xyz);



ALBEDO*=0.14;EMISSION*=0.14;ALPHA*=payload_alpha;

ALBEDO *= 4.0; EMISSION *= 4.0;
}

void light() {
// FloatParameter:5
	float n_out5p0 = Hard_Shadow_min;


// FloatParameter:6
	float n_out6p0 = Hard_Shadow_max;


// Input:2
	vec3 n_out2p0 = NORMAL;


// Input:11
	vec3 n_out11p0 = LIGHT;


// DotProduct:3
	float n_out3p0 = dot(n_out2p0, n_out11p0);


// Fresnel:10
	float n_in10p3 = 10.00000;
	float n_out10p0 = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_in10p3);


// FloatOp:12
	float n_out12p0 = n_out3p0 + n_out10p0;


// SmoothStep:4
	vec3 n_out4p0 = smoothstep(vec3(n_out5p0), vec3(n_out6p0), vec3(n_out12p0));


// FloatParameter:7
	float n_out7p0 = Shadow_Min;


// FloatParameter:9
	float n_out9p0 = Shadow_Max;


// Clamp:8
	vec3 n_out8p0 = clamp(n_out4p0, vec3(n_out7p0), vec3(n_out9p0));


// Output:0
	DIFFUSE_LIGHT = n_out8p0;


}


