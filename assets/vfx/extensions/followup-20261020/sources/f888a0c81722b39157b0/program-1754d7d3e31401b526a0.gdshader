shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float vfx_clock=0.0;
uniform float vfx_alpha=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_schlick_ggx;

uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_Texture : source_color;
uniform sampler2D Add_Texture : source_color, hint_default_black;
uniform sampler2D Multiply_Texture : source_color;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform float Color_Intensity = 1.0;
uniform bool Enable_Proximity_Fade = false;
uniform bool Fresnel_invert = false;
uniform float Fresnel_Power = 1.0;
uniform float Proximity_Fade = 1.0;
uniform sampler2D depth_tex_frg_16 : hint_depth_texture;



void fragment() {
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz; 

// Vector2Parameter:7
	vec2 n_out7p0 = Scale_XY;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (UV - n_in4p2) * n_out7p0 + n_in4p2;


// Vector2Parameter:6
	vec2 n_out6p0 = Speed_XY;


// Input:8
	float n_out8p0 = vfx_clock;


// VectorOp:9
	vec2 n_out9p0 = n_out6p0 * vec2(n_out8p0);


// UVFunc:5
	vec2 n_in5p1 = vec2(1.00000, 1.00000);
	vec2 n_out5p0 = n_out9p0 * n_in5p1 + n_out4p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_Texture, n_out5p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out13p0;
// Texture2D:13
	n_out13p0 = texture(Add_Texture, UV);
	float n_out13p1 = n_out13p0.r;


// FloatOp:15
	float n_out15p0 = n_out3p1 + n_out13p1;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Multiply_Texture, UV);
	float n_out11p1 = n_out11p0.r;


// FloatOp:12
	float n_out12p0 = n_out15p0 * n_out11p1;


	vec4 n_out26p0;
// Texture2D:26
	n_out26p0 = texture(Color_1D_Gradient, vec2(n_out12p0));
	float n_out26p4 = n_out26p0.a;


// FloatParameter:28
	float n_out28p0 = Color_Intensity;


// VectorOp:27
	vec3 n_out27p0 = vec3(n_out26p0.xyz) * vec3(n_out28p0);


// BooleanParameter:20
	bool n_out20p0 = Enable_Proximity_Fade;


// BooleanParameter:23
	bool n_out23p0 = Fresnel_invert;


// FloatParameter:24
	float n_out24p0 = Fresnel_Power;


// Fresnel:21
	float n_out21p0 = n_out23p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out24p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out24p0));


// FloatOp:22
	float n_out22p0 = n_out26p4 * n_out21p0;


// Input:30
	vec4 n_out30p0 = COLOR;
	float n_out30p4 = n_out30p0.a;


// FloatOp:29
	float n_out29p0 = n_out22p0 * n_out30p4;


// FloatParameter:18
	float n_out18p0 = Proximity_Fade;


	float n_out16p0;
// ProximityFade:16
	{
		float __depth_tex = texture(depth_tex_frg_16, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out16p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out18p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:17
	float n_out17p0 = n_out29p0 * n_out16p0;


	float n_out19p0;
// Switch:19
	n_out19p0 = mix(n_out29p0, n_out17p0, float(n_out20p0));


// Output:0
	ALBEDO = n_out27p0;
	ALPHA = n_out19p0;



ALPHA *= vfx_alpha;
}



