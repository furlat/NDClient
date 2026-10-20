shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform bool UseProximityFade = true;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed;
uniform sampler2D Texture : source_color, repeat_enable;
uniform vec2 Texture_substract_scale = vec2(1.000000, 1.000000);
uniform vec2 Texture_substract_speed;
uniform sampler2D Texture_Substract : source_color, hint_default_black, repeat_enable;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;
uniform float Opacity : hint_range(0.0, 1.0) = 0.0;
uniform bool Use_Fresnel = false;
uniform bool Fresnel_Invert;
uniform float Fresnel_Power = 1.0;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// BooleanParameter:38
	bool n_out38p0 = UseProximityFade;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed;


// Input:24
	float n_out24p0 = support_clock;


// VectorOp:25
	vec2 n_out25p0 = n_out21p0 * vec2(n_out24p0);


// UVFunc:26
	vec2 n_in26p1 = vec2(1.00000, 1.00000);
	vec2 n_out26p0 = n_out25p0 * n_in26p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out26p0);
	float n_out10p1 = n_out10p0.r;


// Vector2Parameter:40
	vec2 n_out40p0 = Texture_substract_scale;


// UVFunc:39
	vec2 n_in39p2 = vec2(0.00000, 0.00000);
	vec2 n_out39p0 = (UV - n_in39p2) * n_out40p0 + n_in39p2;


// Vector2Parameter:41
	vec2 n_out41p0 = Texture_substract_speed;


// Input:42
	float n_out42p0 = support_clock;


// VectorOp:43
	vec2 n_out43p0 = n_out41p0 * vec2(n_out42p0);


// UVFunc:44
	vec2 n_in44p1 = vec2(1.00000, 1.00000);
	vec2 n_out44p0 = n_out43p0 * n_in44p1 + n_out39p0;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Texture_Substract, n_out44p0);
	float n_out19p1 = n_out19p0.r;


// FloatOp:18
	float n_out18p0 = n_out10p1 - n_out19p1;


// Clamp:23
	float n_in23p1 = 0.00000;
	float n_in23p2 = 1.00000;
	float n_out23p0 = clamp(n_out18p0, n_in23p1, n_in23p2);


// SmoothStep:17
	float n_in17p1 = 1.00000;
	float n_out17p0 = smoothstep(n_out4p4, n_in17p1, n_out23p0);


// FloatParameter:13
	float n_out13p0 = Proximity_Fade;


	float n_out12p0;
// ProximityFade:12
	{
		float __depth_tex = texture(depth_tex_frg_12, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out12p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out13p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:11
	float n_out11p0 = n_out17p0 * n_out12p0;


	float n_out37p0;
// Switch:37
	n_out37p0 = mix(n_out17p0, n_out11p0, float(n_out38p0));


// FloatParameter:28
	float n_out28p0 = Opacity;


// FloatOp:27
	float n_out27p0 = n_out37p0 * n_out28p0;


// BooleanParameter:34
	bool n_out34p0 = Use_Fresnel;


// BooleanParameter:32
	bool n_out32p0 = Fresnel_Invert;


// FloatParameter:31
	float n_out31p0 = Fresnel_Power;


// Fresnel:29
	float n_out29p0 = n_out32p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0));


	float n_out33p0;
// Switch:33
	float n_in33p2 = 1.00000;
	n_out33p0 = mix(n_in33p2, n_out29p0, float(n_out34p0));


// FloatOp:30
	float n_out30p0 = n_out27p0 * n_out33p0;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out30p0;



ALPHA *= support_envelope;
}




