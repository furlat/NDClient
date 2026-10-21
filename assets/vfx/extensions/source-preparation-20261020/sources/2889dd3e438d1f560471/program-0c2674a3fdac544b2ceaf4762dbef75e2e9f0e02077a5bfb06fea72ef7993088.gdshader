shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;
uniform float vfx_package_offset_support_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform float Base_intensity = 1.0;
uniform vec2 base_scale = vec2(1.000000, 1.000000);
uniform vec2 base_speed = vec2(0.000000, 0.000000);
uniform sampler2D Texture_base : source_color, filter_linear;
uniform sampler2D base_color_1d : source_color, repeat_disable;
uniform vec2 Scale2_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed2_XY = vec2(0.000000, 0.000000);
uniform sampler2D Texture2_Main : source_color, filter_linear;
uniform sampler2D Color2_1D_Gradient2 : source_color, repeat_disable;
uniform float Intensity = 1.0;
uniform sampler2D Texture_alpha : source_color, filter_linear;
uniform float AlphaTreshold : hint_range(0.0, 1.10000002384186);



void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// FloatParameter:85
	float n_out85p0 = Base_intensity;


// Input:81
	vec2 n_out81p0 = UV;


// Vector2Parameter:79
	vec2 n_out79p0 = base_scale;


// UVFunc:80
	vec2 n_in80p2 = vec2(0.00000, 0.00000);
	vec2 n_out80p0 = (n_out81p0 - n_in80p2) * n_out79p0 + n_in80p2;


// Input:75
	float n_out75p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:78
	vec2 n_out78p0 = base_speed;


// VectorOp:76
	vec2 n_out76p0 = vec2(n_out75p0) * n_out78p0;


// UVFunc:77
	vec2 n_in77p1 = vec2(1.00000, 1.00000);
	vec2 n_out77p0 = n_out76p0 * n_in77p1 + n_out80p0;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Texture_base, n_out77p0);
	float n_out9p1 = n_out9p0.r;


	vec4 n_out83p0;
// Texture2D:83
	n_out83p0 = texture(base_color_1d, vec2(n_out9p1));


// VectorOp:84
	vec3 n_out84p0 = vec3(n_out85p0) * vec3(n_out83p0.xyz);


// Input:70
	vec2 n_out70p0 = UV;


// Vector2Parameter:68
	vec2 n_out68p0 = Scale2_XY;


// UVFunc:69
	vec2 n_in69p2 = vec2(0.00000, 0.00000);
	vec2 n_out69p0 = (n_out70p0 - n_in69p2) * n_out68p0 + n_in69p2;


// Input:61
	float n_out61p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:67
	vec2 n_out67p0 = Speed2_XY;


// VectorOp:62
	vec2 n_out62p0 = vec2(n_out61p0) * n_out67p0;


// UVFunc:66
	vec2 n_in66p1 = vec2(1.00000, 1.00000);
	vec2 n_out66p0 = n_out62p0 * n_in66p1 + n_out69p0;


	vec4 n_out71p0;
// Texture2D:71
	n_out71p0 = texture(Texture2_Main, n_out66p0);
	float n_out71p1 = n_out71p0.r;


	vec4 n_out65p0;
// Texture2D:65
	n_out65p0 = texture(Color2_1D_Gradient2, vec2(n_out71p1));


// FloatParameter:54
	float n_out54p0 = Intensity;


// VectorOp:53
	vec3 n_out53p0 = vec3(n_out65p0.xyz) * vec3(n_out54p0);


// VectorOp:86
	vec3 n_out86p0 = n_out84p0 + n_out53p0;


	vec4 n_out74p0;
// Texture2D:74
	n_out74p0 = texture(Texture_alpha, UV);
	float n_out74p1 = n_out74p0.r;


// FloatParameter:55
	float n_out55p0 = AlphaTreshold;


// Output:0
	ALBEDO = n_out86p0;
	ALPHA = n_out74p1;
	ALPHA_SCISSOR_THRESHOLD = n_out55p0;



ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}




