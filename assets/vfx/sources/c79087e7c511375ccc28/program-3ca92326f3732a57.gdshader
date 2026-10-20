shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_movement_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float movement_clock=0.0;
uniform float movement_fade=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform bool Enable_Distortion;
uniform vec2 distortion_scale = vec2(1.000000, 1.000000);
uniform vec2 distortion_speed = vec2(1.000000, 1.000000);
uniform sampler2D DistortionTexture : hint_normal, filter_linear;
uniform float DistortionStregnht = 0.01999999955297;
uniform vec2 scale = vec2(1.000000, 1.000000);
uniform vec2 speed = vec2(1.000000, 1.000000);
uniform sampler2D BaseTexture : source_color, repeat_enable;
uniform sampler2D Multiply_Mask : source_color, repeat_disable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform bool Use_Proximity_Fade = false;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_109 : hint_depth_texture;



void vertex() {
	mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __mvm = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
		__mvm = __mvm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = __mvm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;


}

void fragment() {
vec3 world_pos=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:104
	vec4 n_out104p0 = COLOR;


// BooleanParameter:113
	bool n_out113p0 = Enable_Distortion;


// Input:114
	vec2 n_out114p0 = UV;


// Vector2Parameter:10
	vec2 n_out10p0 = distortion_scale;


// UVFunc:17
	vec2 n_in17p2 = vec2(0.00000, 0.00000);
	vec2 n_out17p0 = (UV - n_in17p2) * n_out10p0 + n_in17p2;


// Input:7
	float n_out7p0 = (vfx_package_seconds()+vfx_package_offset_movement_clock);


// Vector2Parameter:8
	vec2 n_out8p0 = distortion_speed;


// VectorOp:9
	vec2 n_out9p0 = vec2(n_out7p0) * n_out8p0;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out17p0;


	vec4 n_out12p0;
// Texture2D:12
	n_out12p0 = texture(DistortionTexture, n_out6p0);
	float n_out12p1 = n_out12p0.r;
	float n_out12p2 = n_out12p0.g;


// VectorCompose:3
	vec2 n_out3p0 = vec2(n_out12p1, n_out12p2);


// FloatParameter:19
	float n_out19p0 = DistortionStregnht;


// VectorOp:15
	vec2 n_out15p0 = n_out3p0 * vec2(n_out19p0);


// VectorOp:13
	vec2 n_out13p0 = n_out114p0 - n_out15p0;


// Input:112
	vec2 n_out112p0 = UV;


	vec2 n_out111p0;
// Switch:111
	n_out111p0 = mix(n_out112p0, n_out13p0, float(n_out113p0));


// Vector2Parameter:98
	vec2 n_out98p0 = scale;


// UVFunc:97
	vec2 n_in97p2 = vec2(0.00000, 0.00000);
	vec2 n_out97p0 = (n_out111p0 - n_in97p2) * n_out98p0 + n_in97p2;


// Input:94
	float n_out94p0 = (vfx_package_seconds()+vfx_package_offset_movement_clock);


// Vector2Parameter:95
	vec2 n_out95p0 = speed;


// VectorOp:96
	vec2 n_out96p0 = vec2(n_out94p0) * n_out95p0;


// UVFunc:93
	vec2 n_in93p1 = vec2(1.00000, 1.00000);
	vec2 n_out93p0 = n_out96p0 * n_in93p1 + n_out97p0;


	vec4 n_out92p0;
// Texture2D:92
	n_out92p0 = texture(BaseTexture, n_out93p0);
	float n_out92p1 = n_out92p0.r;


	vec4 n_out102p0;
// Texture2D:102
	n_out102p0 = texture(Multiply_Mask, UV);
	float n_out102p1 = n_out102p0.r;


// FloatOp:103
	float n_out103p0 = n_out92p1 * n_out102p1;


	vec4 n_out100p0;
// Texture2D:100
	n_out100p0 = texture(Color1DGradient, vec2(n_out103p0));


// VectorOp:105
	vec4 n_out105p0 = n_out104p0 * n_out100p0;
	float n_out105p4 = n_out105p0.a;


// BooleanParameter:108
	bool n_out108p0 = Use_Proximity_Fade;


// FloatParameter:110
	float n_out110p0 = Proximity_Fade;


	float n_out109p0;
// ProximityFade:109
	{
		float __depth_tex = texture(depth_tex_frg_109, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out109p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out110p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:106
	float n_out106p0 = n_out105p4 * n_out109p0;


	float n_out107p0;
// Switch:107
	n_out107p0 = mix(n_out105p4, n_out106p0, float(n_out108p0));


// Output:0
	ALBEDO = vec3(n_out105p0.xyz);
	ALPHA = n_out107p0;



ALPHA *= movement_fade;

ALPHA *= factory_occurrence_alpha;
}



