shader_type spatial;
uniform float sandbox_source_seconds=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform float Size_Sphere = 0.0;
uniform vec2 details_scale = vec2(1.000000, 1.000000);
uniform vec2 details_velocity = vec2(0.000000, 0.000000);
uniform sampler2D Normal_Distortion_Texture : hint_normal, filter_linear, repeat_enable;
uniform float RefStrenght;
uniform sampler2D Texture_Screen : source_color, filter_linear, hint_screen_texture;
uniform vec2 Disolver_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Noise_Line : source_color, filter_linear, repeat_enable;
uniform float Line_Distortion_Divider = 5.0;
uniform sampler2D Gradient_Disappear : source_color, filter_linear, repeat_disable;
uniform float Gradient_Line : hint_range(0.0, 0.83999997377396) = 0.0;



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
// Input:4
	vec2 n_out4p0 = SCREEN_UV;


// Vector2Parameter:10
	vec2 n_out10p0 = details_scale;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out10p0 + n_in9p2;


// Vector2Parameter:27
	vec2 n_out27p0 = details_velocity;


// Input:29
	float n_out29p0 = sandbox_source_seconds;


// VectorOp:28
	vec2 n_out28p0 = n_out27p0 * vec2(n_out29p0);


// UVFunc:26
	vec2 n_in26p1 = vec2(1.00000, 1.00000);
	vec2 n_out26p0 = n_out28p0 * n_in26p1 + n_out9p0;


	vec4 n_out21p0;
// Texture2D:21
	n_out21p0 = texture(Normal_Distortion_Texture, n_out26p0);
	float n_out21p1 = n_out21p0.r;
	float n_out21p2 = n_out21p0.g;


// VectorCompose:17
	vec2 n_out17p0 = vec2(n_out21p1, n_out21p2);


// MultiplyAdd:8
	vec2 n_in8p1 = vec2(2.00000, 2.00000);
	vec2 n_in8p2 = vec2(-1.00000, -1.00000);
	vec2 n_out8p0 = fma(n_out17p0, n_in8p1, n_in8p2);


// FloatParameter:7
	float n_out7p0 = RefStrenght;


// VectorOp:6
	vec2 n_out6p0 = n_out8p0 * vec2(n_out7p0);


// VectorOp:5
	vec2 n_out5p0 = n_out4p0 - n_out6p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture_Screen, n_out5p0);


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


// FloatParameter:56
	float n_out56p0 = Gradient_Line;


// Step:57
	float n_out57p0 = step(n_out86p1, n_out56p0);


// Output:0
	ALBEDO = vec3(n_out3p0.xyz);
	ALPHA = n_out57p0;


}



