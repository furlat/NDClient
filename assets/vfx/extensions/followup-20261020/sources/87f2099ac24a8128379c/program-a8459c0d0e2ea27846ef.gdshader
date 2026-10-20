shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_opacity=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float Color_Intensity;
uniform vec2 Speed_X_Y;
uniform sampler2D Main_Texture : source_color;
uniform bool Enable_Solid_Texture;
uniform sampler2D Mask_Texture : source_color;
uniform bool Enable_Distortion;
uniform vec2 Distortion_Speed_Mask2;
uniform sampler2D Distortion_Texture : source_color;
uniform float Distortion_Divide_ = 50.0;
uniform sampler2D Mask2_Texture : source_color;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_52 : hint_depth_texture;



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


// BooleanParameter:51
	bool n_out51p0 = Enable_Solid_Texture;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Mask_Texture, UV);
	float n_out33p1 = n_out33p0.r;


// BooleanParameter:47
	bool n_out47p0 = Enable_Distortion;


// Input:45
	vec2 n_out45p0 = UV;


// Input:40
	float n_out40p0 = support_clock;


// Vector2Parameter:42
	vec2 n_out42p0 = Distortion_Speed_Mask2;


// VectorOp:41
	vec2 n_out41p0 = vec2(n_out40p0) * n_out42p0;


// UVFunc:39
	vec2 n_in39p1 = vec2(1.00000, 1.00000);
	vec2 n_out39p0 = n_out41p0 * n_in39p1 + UV;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Distortion_Texture, n_out39p0);
	float n_out38p1 = n_out38p0.r;


// FloatParameter:44
	float n_out44p0 = Distortion_Divide_;


// FloatOp:43
	float n_out43p0 = n_out38p1 / n_out44p0;


// VectorOp:46
	vec2 n_out46p0 = n_out45p0 + vec2(n_out43p0);


	vec2 n_out48p0;
// Switch:48
	n_out48p0 = mix(n_out45p0, n_out46p0, float(n_out47p0));


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Mask2_Texture, n_out48p0);
	float n_out35p1 = n_out35p0.r;


// FloatOp:36
	float n_out36p0 = n_out33p1 * n_out35p1;


// FloatOp:49
	float n_out49p0 = n_out31p1 * n_out36p0;


	float n_out50p0;
// Switch:50
	n_out50p0 = mix(n_out36p0, n_out49p0, float(n_out51p0));


// FloatParameter:54
	float n_out54p0 = Proximity_Fade;


	float n_out52p0;
// ProximityFade:52
	{
		float __depth_tex = texture(depth_tex_frg_52, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out52p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out54p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:53
	float n_out53p0 = n_out50p0 * n_out52p0;


// Output:0
	ALBEDO = vec3(n_out21p0.xyz);
	ALPHA = n_out53p0;



ALPHA *= support_envelope;
}




