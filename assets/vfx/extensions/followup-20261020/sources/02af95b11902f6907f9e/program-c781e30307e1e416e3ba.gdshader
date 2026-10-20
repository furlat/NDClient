shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float Size_Sphere = 0.0;
uniform float Gradient_Line : hint_range(0.0, 1.0) = 0.0;
uniform float Line_Baias = 0.01999999955297;
uniform float SmoothStep : hint_range(0.0, 1.0) = 0.80000001192093;
uniform vec2 Disolver_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Noise_Line : source_color, filter_linear, repeat_enable;
uniform float Line_Distortion_Divider = 5.0;
uniform sampler2D Gradient_Disappear : source_color, filter_linear, repeat_disable;
uniform sampler2D Line_Gradient : source_color, filter_linear, repeat_disable;
uniform bool EnableDistortion = false;
uniform vec2 Distortion_Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Distortion_Speed_XY;
uniform sampler2D Distortion_Texture : source_color, repeat_enable;
uniform float Distortion_Intensity = 0.10000000149012;
uniform vec2 Overlay_Scale = vec2(1.000000, 1.000000);
uniform vec2 Overlay_Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Overlay_Texture : source_color, hint_default_black, filter_linear;
uniform sampler2D Texture_add : source_color, hint_default_black, filter_linear, repeat_disable;
uniform sampler2D Texture_multiply : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_1D_Color : source_color, filter_linear;
uniform float Color_Intensity = 1.0;



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:4
	vec3 n_out4p0 = NORMAL;


// FloatParameter:6
	float n_out6p0 = Size_Sphere;


// VectorOp:5
	vec3 n_out5p0 = n_out4p0 * vec3(n_out6p0);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
// FloatParameter:56
	float n_out56p0 = Gradient_Line;


// FloatParameter:61
	float n_out61p0 = Line_Baias;


// FloatOp:59
	float n_out59p0 = n_out56p0 - n_out61p0;


// FloatParameter:95
	float n_out95p0 = SmoothStep;


// Input:78
	vec2 n_out78p0 = UV;


// Vector2Parameter:83
	vec2 n_out83p0 = Disolver_Scale;


// UVFunc:82
	vec2 n_in82p2 = vec2(0.00000, 0.00000);
	vec2 n_out82p0 = (UV - n_in82p2) * n_out83p0 + n_in82p2;


	vec4 n_out77p0;
// Texture2D:77
	n_out77p0 = texture(Disolver_Noise_Line, n_out82p0);
	float n_out77p1 = n_out77p0.r;


// FloatParameter:91
	float n_out91p0 = Line_Distortion_Divider;


// FloatOp:80
	float n_out80p0 = n_out77p1 / n_out91p0;


// VectorOp:79
	vec2 n_out79p0 = n_out78p0 + vec2(n_out80p0);


	vec4 n_out86p0;
// Texture2D:86
	n_out86p0 = texture(Gradient_Disappear, n_out79p0);
	float n_out86p1 = n_out86p0.r;


// FloatOp:94
	float n_in94p1 = 0.59000;
	float n_out94p0 = pow(n_out86p1, n_in94p1);


// SmoothStep:84
	float n_out84p0 = smoothstep(n_out59p0, n_out95p0, n_out94p0);


	vec4 n_out90p0;
// Texture2D:90
	n_out90p0 = texture(Line_Gradient, vec2(n_out84p0));


// Input:116
	vec2 n_out116p0 = UV;


// BooleanParameter:115
	bool n_out115p0 = EnableDistortion;


// Vector2Parameter:109
	vec2 n_out109p0 = Distortion_Scale_XY;


// UVFunc:108
	vec2 n_in108p2 = vec2(0.00000, 0.00000);
	vec2 n_out108p0 = (UV - n_in108p2) * n_out109p0 + n_in108p2;


// Input:105
	float n_out105p0 = support_clock;


// Vector2Parameter:106
	vec2 n_out106p0 = Distortion_Speed_XY;


// VectorOp:107
	vec2 n_out107p0 = vec2(n_out105p0) * n_out106p0;


// UVFunc:118
	vec2 n_in118p1 = vec2(1.00000, 1.00000);
	vec2 n_out118p0 = n_out107p0 * n_in118p1 + n_out108p0;


	vec4 n_out110p0;
// Texture2D:110
	n_out110p0 = texture(Distortion_Texture, n_out118p0);
	float n_out110p1 = n_out110p0.r;


// FloatParameter:113
	float n_out113p0 = Distortion_Intensity;


// FloatOp:112
	float n_out112p0 = n_out110p1 * n_out113p0;


// FloatFunc:117
	float n_in117p0 = 0.00000;
	float n_out117p0 = 1.0 - n_in117p0;


// FloatOp:119
	float n_out119p0 = n_out112p0 * n_out117p0;


	float n_out114p0;
// Switch:114
	float n_in114p2 = 0.00000;
	n_out114p0 = mix(n_in114p2, n_out119p0, float(n_out115p0));


// VectorOp:120
	vec2 n_out120p0 = n_out116p0 + vec2(n_out114p0);


// Vector2Parameter:43
	vec2 n_out43p0 = Overlay_Scale;


// UVFunc:42
	vec2 n_in42p2 = vec2(0.00000, 0.00000);
	vec2 n_out42p0 = (n_out120p0 - n_in42p2) * n_out43p0 + n_in42p2;


// Vector2Parameter:44
	vec2 n_out44p0 = Overlay_Velocity;


// Input:47
	float n_out47p0 = support_clock;


// VectorOp:45
	vec2 n_out45p0 = n_out44p0 * vec2(n_out47p0);


// UVFunc:46
	vec2 n_in46p1 = vec2(1.00000, 1.00000);
	vec2 n_out46p0 = n_out45p0 * n_in46p1 + n_out42p0;


	vec4 n_out41p0;
// Texture2D:41
	n_out41p0 = texture(Overlay_Texture, n_out46p0);
	float n_out41p1 = n_out41p0.r;


	vec4 n_out99p0;
// Texture2D:99
	n_out99p0 = texture(Texture_add, UV);
	float n_out99p1 = n_out99p0.r;


// FloatOp:100
	float n_out100p0 = n_out41p1 + n_out99p1;


	vec4 n_out102p0;
// Texture2D:102
	n_out102p0 = texture(Texture_multiply, UV);
	float n_out102p1 = n_out102p0.r;


// FloatOp:103
	float n_out103p0 = n_out100p0 * n_out102p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out103p0, n_in25p1, n_in25p2);


// FloatOp:97
	float n_out97p0 = n_out84p0 + n_out25p0;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Gradient_1D_Color, vec2(n_out97p0));
	float n_out38p4 = n_out38p0.a;


// FloatParameter:122
	float n_out122p0 = Color_Intensity;


// VectorOp:121
	vec3 n_out121p0 = vec3(n_out38p0.xyz) * vec3(n_out122p0);


// VectorOp:63
	vec3 n_out63p0 = vec3(n_out90p0.xyz) + n_out121p0;


// Step:57
	float n_out57p0 = step(n_out86p1, n_out56p0);


// FloatOp:96
	float n_out96p0 = n_out38p4 * n_out57p0;


// Output:0
	ALBEDO = n_out63p0;
	ALPHA = n_out96p0;



ALPHA *= support_envelope;
}



