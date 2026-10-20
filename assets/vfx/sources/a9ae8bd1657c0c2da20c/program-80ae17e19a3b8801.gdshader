shader_type spatial;
uniform float owned_clock=0.;

uniform vec4 recipient_native_colour=vec4(1.0);

render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_prepass_alpha;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Disolver_Texture : source_color, repeat_enable;
uniform sampler2D Multiply_Texture : source_color, repeat_disable;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform bool UseFresnel = false;
uniform vec2 Screen_Distortion_Speed;
uniform vec2 Screen_Distortion_Scale = vec2(1.000000, 1.000000);
uniform bool FresnelInver = false;
uniform float FresnelPower = 1.0;
uniform sampler2D Metallic_Texture : source_color, repeat_disable;
uniform sampler2D Texture_Roughtness : source_color, repeat_enable;
uniform sampler2D Roughtness_1D_Gradient : source_color, repeat_disable;
uniform float Ambient_light : hint_range(0.0, 1.0) = 0.30000001192093;
uniform sampler2D Normal_Texture : hint_normal, repeat_enable;
uniform float Normal_Map_Depth = 1.0;





void fragment() {
// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed_XY;


// Input:31
	float n_out31p0 = 0.180000000;


// VectorOp:32
	vec2 n_out32p0 = n_out21p0 * vec2(n_out31p0);


// UVFunc:20
	vec2 n_in20p1 = vec2(1.00000, 1.00000);
	vec2 n_out20p0 = n_out32p0 * n_in20p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Disolver_Texture, n_out20p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out91p0;
// Texture2D:91
	n_out91p0 = texture(Multiply_Texture, UV);
	float n_out91p1 = n_out91p0.r;


// FloatOp:92
	float n_out92p0 = n_out10p1 * n_out91p1;


	vec4 n_out30p0;
// Texture2D:30
	n_out30p0 = texture(Color_1D_Gradient, vec2(n_out92p0));
	float n_out30p4 = n_out30p0.a;


// Input:36
	vec4 n_out36p0 = recipient_native_colour;


// VectorOp:35
	vec3 n_out35p0 = vec3(n_out30p0.xyz) * vec3(n_out36p0.xyz);


// BooleanParameter:85
	bool n_out85p0 = UseFresnel;


// Vector2Parameter:80
	vec2 n_out80p0 = Screen_Distortion_Speed;


// Input:79
	float n_out79p0 = 0.180000000;


// VectorOp:81
	vec2 n_out81p0 = n_out80p0 * vec2(n_out79p0);


// UVFunc:76
	vec2 n_in76p1 = vec2(1.00000, 1.00000);
	vec2 n_out76p0 = n_out81p0 * n_in76p1 + UV;


// Vector2Parameter:78
	vec2 n_out78p0 = Screen_Distortion_Scale;


// UVFunc:77
	vec2 n_in77p2 = vec2(0.00000, 0.00000);
	vec2 n_out77p0 = (n_out76p0 - n_in77p2) * n_out78p0 + n_in77p2;


// Input:87
	vec3 n_out87p0 = NORMAL;


// VectorOp:88
	vec3 n_out88p0 = vec3(n_out77p0, 0.0) + n_out87p0;


// BooleanParameter:82
	bool n_out82p0 = FresnelInver;


// FloatParameter:83
	float n_out83p0 = FresnelPower;


// Fresnel:84
	float n_out84p0 = n_out82p0 ? (pow(clamp(dot(n_out88p0, VIEW), 0.0, 1.0), n_out83p0)) : (pow(1.0 - clamp(dot(n_out88p0, VIEW), 0.0, 1.0), n_out83p0));


	float n_out86p0;
// Switch:86
	float n_in86p2 = 1.00000;
	n_out86p0 = mix(n_in86p2, n_out84p0, float(n_out85p0));


// Input:4
	vec4 n_out4p0 = recipient_native_colour;
	float n_out4p4 = n_out4p0.a;


// Step:74
	float n_out74p0 = step(n_out4p4, n_out92p0);


// FloatOp:75
	float n_out75p0 = n_out30p4 * n_out74p0;


// FloatOp:89
	float n_out89p0 = n_out86p0 * n_out75p0;


// Reroute:28
	vec2 n_out28p0 = n_out20p0;


	vec4 n_out26p0;
// Texture2D:26
	n_out26p0 = texture(Metallic_Texture, n_out28p0);
	float n_out26p1 = n_out26p0.r;


	vec4 n_out25p0;
// Texture2D:25
	n_out25p0 = texture(Texture_Roughtness, n_out28p0);
	float n_out25p1 = n_out25p0.r;


	vec4 n_out34p0;
// Texture2D:34
	n_out34p0 = texture(Roughtness_1D_Gradient, vec2(n_out25p1));
	float n_out34p1 = n_out34p0.r;


// FloatParameter:65
	float n_out65p0 = Ambient_light;


// VectorOp:66
	vec3 n_out66p0 = n_out35p0 * vec3(n_out65p0);


	vec4 n_out23p0;
// Texture2D:23
	n_out23p0 = texture(Normal_Texture, n_out28p0);


// FloatParameter:37
	float n_out37p0 = Normal_Map_Depth;


// Output:0
	ALBEDO = n_out35p0;
	ALPHA = n_out89p0;
	METALLIC = n_out26p1;
	ROUGHNESS = n_out34p1;
	EMISSION = n_out66p0;
	NORMAL_MAP = vec3(n_out23p0.xyz);
	NORMAL_MAP_DEPTH = n_out37p0;



float recipient_native_gain=0.080000000*(.94+.06*cos(owned_clock*1.5707963267948966));
ALPHA *= recipient_native_gain;
}


