shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

uniform float ward_seconds=0.0;
uniform float ward_alpha=0.0;
varying vec3 actual_payload_position;
uniform vec3 payload_origin=vec3(0.0);
uniform float payload_radius=2.6;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_toon, depth_prepass_alpha;

uniform sampler2D Base_noise2 : source_color, repeat_enable;
uniform vec2 Speed_XY2;
uniform vec2 Scale_XY2 = vec2(1.000000, 1.000000);
uniform bool Fresnel_Invert = false;
uniform float Fresnel_power = 1.0;
uniform sampler2D Fresnel_Gradient_Color_1D : source_color, repeat_disable;
uniform sampler2D Texture_substract : source_color, hint_default_black, repeat_disable;
uniform sampler2D Texture_add : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_Color_1D2 : source_color, repeat_disable;
uniform float Color_Intensity2 = 1.0;
uniform sampler2D Texture_substract_end : source_color, hint_default_black, repeat_disable;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;



void fragment() {
// Vector2Parameter:43
	vec2 n_out43p0 = Scale_XY2;


// UVFunc:39
	vec2 n_in39p2 = vec2(0.00000, 0.00000);
	vec2 n_out39p0 = (UV - n_in39p2) * n_out43p0 + n_in39p2;


// Vector2Parameter:41
	vec2 n_out41p0 = Speed_XY2;


// Input:40
	float n_out40p0 = ward_seconds;


// VectorOp:42
	vec2 n_out42p0 = n_out41p0 * vec2(n_out40p0);


// UVFunc:38
	vec2 n_in38p1 = vec2(1.00000, 1.00000);
	vec2 n_out38p0 = n_out42p0 * n_in38p1 + n_out39p0;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Base_noise2, n_out38p0);
	float n_out33p1 = n_out33p0.r;


// BooleanParameter:23
	bool n_out23p0 = Fresnel_Invert;


// FloatParameter:22
	float n_out22p0 = Fresnel_power;


// Fresnel:21
	float n_out21p0 = n_out23p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0));


	vec4 n_out52p0;
// Texture2D:52
	n_out52p0 = texture(Fresnel_Gradient_Color_1D, vec2(n_out21p0));
	float n_out52p1 = n_out52p0.r;


// FloatOp:14
	float n_out14p0 = n_out33p1 + n_out52p1;


	vec4 n_out36p0;
// Texture2D:36
	n_out36p0 = texture(Texture_substract, UV);
	float n_out36p1 = n_out36p0.r;


// FloatOp:45
	float n_out45p0 = n_out14p0 * n_out36p1;


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Texture_add, UV);
	float n_out35p1 = n_out35p0.r;


// FloatOp:44
	float n_out44p0 = n_out45p0 + n_out35p1;


// Clamp:46
	float n_in46p1 = 0.00000;
	float n_in46p2 = 1.00000;
	float n_out46p0 = clamp(n_out44p0, n_in46p1, n_in46p2);


	vec4 n_out48p0;
// Texture2D:48
	n_out48p0 = texture(Gradient_Color_1D2, vec2(n_out46p0));
	float n_out48p4 = n_out48p0.a;


// FloatParameter:50
	float n_out50p0 = Color_Intensity2;


// VectorOp:49
	vec3 n_out49p0 = vec3(n_out48p0.xyz) * vec3(n_out50p0);


	vec4 n_out54p0;
// Texture2D:54
	n_out54p0 = texture(Texture_substract_end, UV);
	float n_out54p1 = n_out54p0.r;


// FloatOp:55
	float n_out55p0 = n_out48p4 * n_out54p1;


// FloatParameter:59
	float n_out59p0 = Opacity;


// FloatOp:58
	float n_out58p0 = n_out55p0 * n_out59p0;


// Clamp:57
	float n_in57p1 = 0.00000;
	float n_in57p2 = 1.00000;
	float n_out57p0 = clamp(n_out58p0, n_in57p1, n_in57p2);


// Output:0
	ALBEDO = n_out49p0;
	ALPHA = n_out57p0;



ALBEDO*=0.42;
EMISSION*=0.42;
ALPHA*=ward_alpha;

ALPHA*=smoothstep(0.0,0.055,actual_payload_position.y-payload_origin.y)*(1.0-smoothstep(payload_radius-0.12,payload_radius,length(actual_payload_position.xz-payload_origin.xz)));

ALPHA *= factory_occurrence_alpha;
}


void vertex(){
vec4 actual_payload_world=MODEL_MATRIX*vec4(VERTEX,1.0);actual_payload_position=actual_payload_world.xyz;
}


