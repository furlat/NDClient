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
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform float Intensity = 1.0;
uniform bool Use_Fresnel = false;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Texture : source_color, filter_linear, repeat_enable;
uniform sampler2D Add_Texture : source_color, hint_default_black, filter_linear, repeat_disable;
uniform sampler2D Multiply_Texture : source_color, filter_linear, repeat_disable;
uniform bool Fresnel_Invert = false;
uniform float fresnel = 0.0;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// FloatParameter:40
	float n_out40p0 = Intensity;


// VectorOp:39
	vec3 n_out39p0 = vec3(n_out4p0.xyz) * vec3(n_out40p0);


// BooleanParameter:46
	bool n_out46p0 = Use_Fresnel;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Input:23
	float n_out23p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:25
	vec2 n_out25p0 = Velocity;


// VectorOp:24
	vec2 n_out24p0 = vec2(n_out23p0) * n_out25p0;


// UVFunc:17
	vec2 n_in17p1 = vec2(1.00000, 1.00000);
	vec2 n_out17p0 = n_out24p0 * n_in17p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out17p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Add_Texture, UV);
	float n_out35p1 = n_out35p0.r;


// FloatOp:37
	float n_out37p0 = n_out10p1 + n_out35p1;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Multiply_Texture, UV);
	float n_out33p1 = n_out33p0.r;


// FloatOp:32
	float n_out32p0 = n_out37p0 * n_out33p1;


// Clamp:38
	float n_in38p1 = 0.00000;
	float n_in38p2 = 1.00000;
	float n_out38p0 = clamp(n_out32p0, n_in38p1, n_in38p2);


// BooleanParameter:44
	bool n_out44p0 = Fresnel_Invert;


// FloatParameter:42
	float n_out42p0 = fresnel;


// Fresnel:43
	float n_out43p0 = n_out44p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out42p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out42p0));


// FloatOp:41
	float n_out41p0 = n_out38p0 * n_out43p0;


	float n_out45p0;
// Switch:45
	n_out45p0 = mix(n_out38p0, n_out41p0, float(n_out46p0));


// FloatOp:31
	float n_out31p0 = n_out4p4 * n_out45p0;


// Output:0
	ALBEDO = n_out39p0;
	ALPHA = n_out31p0;



ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}




