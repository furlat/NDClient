shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float factory_occurrence_alpha=1.0;

uniform float receive_layer_alpha=1.0;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_prepass_alpha, unshaded;

uniform float Color_Intensity = 1.0;
uniform vec2 Scale_Texture = vec2(1.000000, 1.000000);
uniform vec2 Velocity_vector;
uniform sampler2D Noise_Texture : source_color, repeat_enable;
uniform float aura_power = 1.0;
uniform sampler2D Add_Texture_Mask : source_color, hint_default_black, filter_linear, repeat_disable;
uniform vec2 Multiply_Offset = vec2(0.000000, 0.000000);
uniform sampler2D Multiply_Texture_Mask : source_color, filter_linear, repeat_disable;
uniform sampler2D Color_1D_gradient : source_color, filter_linear, repeat_disable;
uniform vec2 Alpha_Gradient_SCALE = vec2(1.000000, 1.000000);
uniform sampler2D Alpha_Gradient : source_color, repeat_disable;



void fragment() {
// FloatParameter:55
	float n_out55p0 = Color_Intensity;


// Vector2Parameter:41
	vec2 n_out41p0 = Scale_Texture;


// UVFunc:40
	vec2 n_in40p2 = vec2(0.00000, 0.00000);
	vec2 n_out40p0 = (UV - n_in40p2) * n_out41p0 + n_in40p2;


// Input:7
	float n_out7p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:8
	vec2 n_out8p0 = Velocity_vector;


// VectorOp:9
	vec2 n_out9p0 = vec2(n_out7p0) * n_out8p0;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out40p0;


	vec4 n_out5p0;
// Texture2D:5
	n_out5p0 = texture(Noise_Texture, n_out6p0);
	float n_out5p1 = n_out5p0.r;


// FloatParameter:44
	float n_out44p0 = aura_power;


// FloatOp:43
	float n_out43p0 = pow(n_out5p1, n_out44p0);


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Add_Texture_Mask, UV);
	float n_out33p1 = n_out33p0.r;


// FloatOp:34
	float n_out34p0 = n_out43p0 + n_out33p1;


// Clamp:42
	float n_in42p1 = 0.00000;
	float n_in42p2 = 1.00000;
	float n_out42p0 = clamp(n_out34p0, n_in42p1, n_in42p2);


// Vector2Parameter:39
	vec2 n_out39p0 = Multiply_Offset;


// UVFunc:18
	vec2 n_in18p1 = vec2(1.00000, 1.00000);
	vec2 n_out18p0 = n_out39p0 * n_in18p1 + UV;


	vec4 n_out12p0;
// Texture2D:12
	n_out12p0 = texture(Multiply_Texture_Mask, n_out18p0);
	float n_out12p1 = n_out12p0.r;


// FloatOp:10
	float n_out10p0 = n_out42p0 * n_out12p1;


	vec4 n_out36p0;
// Texture2D:36
	n_out36p0 = texture(Color_1D_gradient, vec2(n_out10p0));
	float n_out36p4 = n_out36p0.a;


// VectorOp:54
	vec3 n_out54p0 = vec3(n_out55p0) * vec3(n_out36p0.xyz);


// Vector2Parameter:53
	vec2 n_out53p0 = Alpha_Gradient_SCALE;


// UVFunc:52
	vec2 n_in52p2 = vec2(0.00000, 0.00000);
	vec2 n_out52p0 = (UV - n_in52p2) * n_out53p0 + n_in52p2;


	vec4 n_out46p0;
// Texture2D:46
	n_out46p0 = texture(Alpha_Gradient, n_out52p0);
	float n_out46p1 = n_out46p0.r;


// FloatOp:47
	float n_out47p0 = n_out36p4 * n_out46p1;


// Input:51
	vec4 n_out51p0 = COLOR;
	float n_out51p4 = n_out51p0.a;


// FloatOp:38
	float n_out38p0 = n_out47p0 * n_out51p4;


// Output:0
	ALBEDO = n_out54p0;
	ALPHA = n_out38p0;



ALPHA *= support_envelope;

ALPHA *= receive_layer_alpha;

ALPHA *= factory_occurrence_alpha;
}



