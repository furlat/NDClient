shader_type spatial;
uniform float vfx_clock=0.0;
uniform float vfx_alpha=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform float Color_Intensity = 1.0;
uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_Texture : source_color;
uniform sampler2D Disolver_Texture : source_color, filter_linear, repeat_enable;
uniform sampler2D Disolver_Add_Texture : source_color, hint_default_black, filter_linear, repeat_disable;
uniform sampler2D Disolver_Multiply_Texture : source_color, filter_linear, repeat_disable;
uniform float Alpha_Treshold : hint_range(0.02999999932945, 1.0) = 0.0;



void fragment() {
// FloatParameter:27
	float n_out27p0 = Color_Intensity;


// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:10
	vec2 n_out10p0 = Speed_XY;


// Input:12
	float n_out12p0 = vfx_clock;


// VectorOp:11
	vec2 n_out11p0 = n_out10p0 * vec2(n_out12p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out11p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_Texture, n_out8p0);
	float n_out3p4 = n_out3p0.a;


// VectorOp:26
	vec3 n_out26p0 = vec3(n_out27p0) * vec3(n_out3p0.xyz);


	vec4 n_out31p0;
// Texture2D:31
	n_out31p0 = texture(Disolver_Texture, UV);
	float n_out31p1 = n_out31p0.r;


	vec4 n_out42p0;
// Texture2D:42
	n_out42p0 = texture(Disolver_Add_Texture, UV);
	float n_out42p1 = n_out42p0.r;


// FloatOp:44
	float n_out44p0 = n_out31p1 + n_out42p1;


	vec4 n_out40p0;
// Texture2D:40
	n_out40p0 = texture(Disolver_Multiply_Texture, UV);
	float n_out40p1 = n_out40p0.r;


// FloatOp:39
	float n_out39p0 = n_out44p0 * n_out40p1;


// Clamp:45
	float n_in45p1 = 0.00000;
	float n_in45p2 = 1.00000;
	float n_out45p0 = clamp(n_out39p0, n_in45p1, n_in45p2);


// FloatOp:38
	float n_out38p0 = n_out3p4 * n_out45p0;


// FloatParameter:46
	float n_out46p0 = Alpha_Treshold;


// Output:0
	ALBEDO = n_out26p0;
	ALPHA = n_out38p0;
	ALPHA_SCISSOR_THRESHOLD = n_out46p0;



ALBEDO=clamp(ALBEDO,vec3(0.035,0.025,0.045),vec3(1.0));

ALPHA *= vfx_alpha;
}


