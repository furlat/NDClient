shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_opacity=1.0;
render_mode blend_add, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float Color_Intensity;
uniform vec2 Speed_X_Y;
uniform sampler2D Main_Texture : source_color;
uniform sampler2D Mask_Texture : source_color;
uniform sampler2D Mask2_Texture : source_color;
uniform sampler2D depth_tex_frg_38 : hint_depth_texture;



void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// FloatParameter:22
	float n_out22p0 = Color_Intensity;


// Input:20
	vec4 n_out20p0 = COLOR;


// VectorOp:23
	vec4 n_out23p0 = vec4(n_out22p0) * n_out20p0;


	vec2 n_out5p0;
// UVPolarCoord:5
	vec2 n_in5p1 = vec2(0.50000, 0.50000);
	float n_in5p2 = 1.00000;
	float n_in5p3 = 1.00000;
	{
		vec2 __dir = UV - n_in5p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out5p0 = vec2(__radius * n_in5p2, __angle * n_in5p3);
	}


// Input:9
	float n_out9p0 = support_clock;


// Vector2Parameter:11
	vec2 n_out11p0 = Speed_X_Y;


// VectorOp:10
	vec2 n_out10p0 = vec2(n_out9p0) * n_out11p0;


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out10p0 * n_in8p1 + n_out5p0;


	vec4 n_out31p0;
// Texture2D:31
	n_out31p0 = texture(Main_Texture, n_out8p0);
	float n_out31p1 = n_out31p0.r;


// VectorOp:21
	vec4 n_out21p0 = n_out23p0 * vec4(n_out31p1);


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Mask_Texture, UV);
	float n_out33p1 = n_out33p0.r;


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Mask2_Texture, UV);
	float n_out35p1 = n_out35p0.r;


// FloatOp:36
	float n_out36p0 = n_out33p1 * n_out35p1;


	float n_out38p0;
// ProximityFade:38
	float n_in38p0 = 1.00000;
	{
		float __depth_tex = texture(depth_tex_frg_38, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out38p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_in38p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:37
	float n_out37p0 = n_out36p0 * n_out38p0;


// Output:0
	ALBEDO = vec3(n_out21p0.xyz);
	ALPHA = n_out37p0;



ALPHA *= support_envelope;
}




