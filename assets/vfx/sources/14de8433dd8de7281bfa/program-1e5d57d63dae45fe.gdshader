shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_movement_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float movement_clock=0.0;
uniform float movement_fade=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_toon, shadows_disabled;

uniform vec2 Alpha_Scale = vec2(1.000000, 1.000000);
uniform vec2 Alpha_pivot = vec2(1.000000, 1.000000);
uniform vec2 Alpha_Speed = vec2(0.000000, 0.000000);
uniform sampler2D Alpha_Texture : source_color, filter_linear;
uniform sampler2D Multiply_Mask : source_color, filter_linear, repeat_disable;
uniform vec2 Dissolver_Scale2 = vec2(1.000000, 1.000000);
uniform vec2 Dissolver_pivot2 = vec2(1.000000, 1.000000);
uniform vec2 Speed_disolver = vec2(0.000000, 0.000000);
uniform sampler2D dissolver_texture : source_color, filter_linear;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool Enable_Proximity_Fade = true;
uniform float ProximityFade = 1.0;
uniform sampler2D depth_tex_frg_44 : hint_depth_texture;
uniform bool Enable_Fresnel = true;
uniform bool Invert_Fresnel;
uniform float Fresnel_power = 0.5;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
vec3 world_pos=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:3
	vec4 n_out3p0 = COLOR;
	float n_out3p4 = n_out3p0.a;


// Vector2Parameter:36
	vec2 n_out36p0 = Alpha_Scale;


// Vector2Parameter:37
	vec2 n_out37p0 = Alpha_pivot;


// UVFunc:30
	vec2 n_out30p0 = (UV - n_out37p0) * n_out36p0 + n_out37p0;


// Input:22
	float n_out22p0 = (vfx_package_seconds()+vfx_package_offset_movement_clock);


// Vector2Parameter:23
	vec2 n_out23p0 = Alpha_Speed;


// VectorOp:24
	vec2 n_out24p0 = vec2(n_out22p0) * n_out23p0;


// UVFunc:21
	vec2 n_in21p1 = vec2(1.00000, 1.00000);
	vec2 n_out21p0 = n_out24p0 * n_in21p1 + n_out30p0;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Alpha_Texture, n_out21p0);
	float n_out19p1 = n_out19p0.r;


	vec4 n_out60p0;
// Texture2D:60
	n_out60p0 = texture(Multiply_Mask, UV);
	float n_out60p1 = n_out60p0.r;


// FloatOp:58
	float n_out58p0 = n_out19p1 * n_out60p1;


// Vector2Parameter:39
	vec2 n_out39p0 = Dissolver_Scale2;


// Vector2Parameter:38
	vec2 n_out38p0 = Dissolver_pivot2;


// UVFunc:31
	vec2 n_out31p0 = (UV - n_out38p0) * n_out39p0 + n_out38p0;


// Input:25
	float n_out25p0 = (vfx_package_seconds()+vfx_package_offset_movement_clock);


// Vector2Parameter:26
	vec2 n_out26p0 = Speed_disolver;


// VectorOp:29
	vec2 n_out29p0 = vec2(n_out25p0) * n_out26p0;


// UVFunc:28
	vec2 n_in28p1 = vec2(1.00000, 1.00000);
	vec2 n_out28p0 = n_out29p0 * n_in28p1 + n_out31p0;


	vec4 n_out17p0;
// Texture2D:17
	n_out17p0 = texture(dissolver_texture, n_out28p0);
	float n_out17p1 = n_out17p0.r;


// SmoothStep:5
	float n_in5p1 = 1.00000;
	float n_out5p0 = smoothstep(n_out17p1, n_in5p1, n_out3p4);


// FloatOp:7
	float n_out7p0 = n_out58p0 - n_out5p0;


// FloatParameter:51
	float n_out51p0 = Opacity;


// FloatOp:50
	float n_out50p0 = n_out7p0 * n_out51p0;


// Clamp:49
	float n_in49p1 = 0.00000;
	float n_in49p2 = 1.00000;
	float n_out49p0 = clamp(n_out50p0, n_in49p1, n_in49p2);


// BooleanParameter:48
	bool n_out48p0 = Enable_Proximity_Fade;


// FloatParameter:46
	float n_out46p0 = ProximityFade;


	float n_out44p0;
// ProximityFade:44
	{
		float __depth_tex = texture(depth_tex_frg_44, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out44p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out46p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


	float n_out47p0;
// Switch:47
	float n_in47p2 = 1.00000;
	n_out47p0 = mix(n_in47p2, n_out44p0, float(n_out48p0));


// FloatOp:45
	float n_out45p0 = n_out49p0 * n_out47p0;


// BooleanParameter:55
	bool n_out55p0 = Enable_Fresnel;


// BooleanParameter:57
	bool n_out57p0 = Invert_Fresnel;


// FloatParameter:56
	float n_out56p0 = Fresnel_power;


// Fresnel:52
	float n_out52p0 = n_out57p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out56p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out56p0));


	float n_out54p0;
// Switch:54
	float n_in54p2 = 1.00000;
	n_out54p0 = mix(n_in54p2, n_out52p0, float(n_out55p0));


// FloatOp:53
	float n_out53p0 = n_out45p0 * n_out54p0;


// Output:0
	ALBEDO = vec3(n_out3p0.xyz);
	ALPHA = n_out53p0;



ALPHA *= movement_fade;
}


