shader_type spatial;
uniform float sandbox_source_seconds=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform bool EnableDistortion = false;
uniform vec2 Distortion_Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Distortion_Speed_XY;
uniform sampler2D Distortion_Texture : source_color, repeat_enable;
uniform float Distortion_Intensity = 0.10000000149012;
uniform vec2 Overlay_Scale = vec2(1.000000, 1.000000);
uniform vec2 Overlay_Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Overlay_Texture : source_color, hint_default_black, filter_linear;
uniform sampler2D Texture_add : source_color, hint_default_black, filter_linear, repeat_disable;
uniform vec2 Multiply_scale = vec2(1.000000, 1.000000);
uniform vec2 Multiply_Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Texture_multiply : source_color, filter_linear, repeat_enable;
uniform sampler2D Texture_multiply2 : source_color, filter_linear, repeat_disable;
uniform sampler2D Gradient_1D_Color : source_color, filter_linear, repeat_disable;
uniform float Color_Intensity = 1.0;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;



void fragment() {
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
	float n_out105p0 = sandbox_source_seconds;


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
	float n_out47p0 = sandbox_source_seconds;


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


// Vector2Parameter:131
	vec2 n_out131p0 = Multiply_scale;


// UVFunc:134
	vec2 n_in134p2 = vec2(0.00000, 0.00000);
	vec2 n_out134p0 = (UV - n_in134p2) * n_out131p0 + n_in134p2;


// Vector2Parameter:132
	vec2 n_out132p0 = Multiply_Velocity;


// Input:129
	float n_out129p0 = sandbox_source_seconds;


// VectorOp:130
	vec2 n_out130p0 = n_out132p0 * vec2(n_out129p0);


// UVFunc:133
	vec2 n_in133p1 = vec2(1.00000, 1.00000);
	vec2 n_out133p0 = n_out130p0 * n_in133p1 + n_out134p0;


	vec4 n_out102p0;
// Texture2D:102
	n_out102p0 = texture(Texture_multiply, n_out133p0);
	float n_out102p1 = n_out102p0.r;


// FloatOp:103
	float n_out103p0 = n_out100p0 * n_out102p1;


	vec4 n_out136p0;
// Texture2D:136
	n_out136p0 = texture(Texture_multiply2, UV);
	float n_out136p1 = n_out136p0.r;


// FloatOp:135
	float n_out135p0 = n_out103p0 * n_out136p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out135p0, n_in25p1, n_in25p2);


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Gradient_1D_Color, vec2(n_out25p0));
	float n_out38p4 = n_out38p0.a;


// FloatParameter:122
	float n_out122p0 = Color_Intensity;


// VectorOp:121
	vec3 n_out121p0 = vec3(n_out38p0.xyz) * vec3(n_out122p0);


// FloatParameter:139
	float n_out139p0 = Opacity;


// FloatOp:138
	float n_out138p0 = n_out38p4 * n_out139p0;


// Output:0
	ALBEDO = n_out121p0;
	ALPHA = n_out138p0;


}



