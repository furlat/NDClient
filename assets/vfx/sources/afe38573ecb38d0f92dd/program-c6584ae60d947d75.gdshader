shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec4 Color : source_color;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed;
uniform sampler2D smoke_texture : source_color;
uniform float Power_Contrast = 1.0;
uniform bool dissolver_radial_uv = false;
uniform float Mask_Zoom_Strenght = 1.0;
uniform float Mask_repeat = 1.0;
uniform vec2 Mask_Scale = vec2(1.000000, 1.000000);
uniform vec2 Mask_pivot = vec2(1.000000, 1.000000);
uniform sampler2D smake_mask : source_color;
uniform float ProximityFade = 1.0;
uniform sampler2D depth_tex_frg_25 : hint_depth_texture;



void vertex() {
	mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __wm = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		__wm = __wm * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		__wm = __wm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = VIEW_MATRIX * __wm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;


}

void fragment() {
// ColorParameter:30
	vec4 n_out30p0 = Color;


// Vector2Parameter:15
	vec2 n_out15p0 = Scale;


// UVFunc:14
	vec2 n_in14p2 = vec2(0.00000, 0.00000);
	vec2 n_out14p0 = (UV - n_in14p2) * n_out15p0 + n_in14p2;


// Input:11
	float n_out11p0 = (vfx_package_seconds()+vfx_package_offset_support_clock);


// Vector2Parameter:12
	vec2 n_out12p0 = Speed;


// VectorOp:13
	vec2 n_out13p0 = vec2(n_out11p0) * n_out12p0;


// UVFunc:10
	vec2 n_in10p1 = vec2(1.00000, 1.00000);
	vec2 n_out10p0 = n_out13p0 * n_in10p1 + n_out14p0;


	vec4 n_out7p0;
// Texture2D:7
	n_out7p0 = texture(smoke_texture, n_out10p0);
	float n_out7p1 = n_out7p0.r;


// FloatParameter:32
	float n_out32p0 = Power_Contrast;


// FloatOp:31
	float n_out31p0 = pow(n_out7p1, n_out32p0);


// BooleanParameter:22
	bool n_out22p0 = dissolver_radial_uv;


// FloatParameter:19
	float n_out19p0 = Mask_Zoom_Strenght;


// FloatParameter:20
	float n_out20p0 = Mask_repeat;


	vec2 n_out17p0;
// UVPolarCoord:17
	vec2 n_in17p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = UV - n_in17p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out17p0 = vec2(__radius * n_out19p0, __angle * n_out20p0);
	}


// Vector2Parameter:21
	vec2 n_out21p0 = Mask_Scale;


// Vector2Parameter:23
	vec2 n_out23p0 = Mask_pivot;


// UVFunc:18
	vec2 n_out18p0 = (UV - n_out23p0) * n_out21p0 + n_out23p0;


	vec2 n_out24p0;
// Switch:24
	n_out24p0 = mix(n_out18p0, n_out17p0, float(n_out22p0));


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(smake_mask, n_out24p0);
	float n_out9p1 = n_out9p0.r;


// FloatOp:16
	float n_out16p0 = n_out31p0 * n_out9p1;


// Input:28
	vec4 n_out28p0 = COLOR;
	float n_out28p4 = n_out28p0.a;


// FloatOp:27
	float n_out27p0 = n_out16p0 * n_out28p4;


// FloatParameter:29
	float n_out29p0 = ProximityFade;


	float n_out25p0;
// ProximityFade:25
	{
		float __depth_tex = texture(depth_tex_frg_25, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out25p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out29p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:26
	float n_out26p0 = n_out27p0 * n_out25p0;


// Output:0
	ALBEDO = vec3(n_out30p0.xyz);
	ALPHA = n_out26p0;



ALPHA *= support_envelope;
}


