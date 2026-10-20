shader_type spatial;
uniform float source_clock=0.0;
uniform mat4 sleep_world_to_source = mat4(1.0);
uniform float sleep_opacity = 1.0;
uniform float sleep_radius_units = 4.0;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec4 Color : source_color;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed;
uniform float LOD_min = 0.0;
uniform float LOD_max = 8.0;
uniform sampler2D smoke_texture : source_color;
uniform sampler2D smake_mask : source_color;
uniform bool Enable_Proximity_Fade = true;
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
	float n_out11p0 = source_clock;


// Vector2Parameter:12
	vec2 n_out12p0 = Speed;


// VectorOp:13
	vec2 n_out13p0 = vec2(n_out11p0) * n_out12p0;


// UVFunc:10
	vec2 n_in10p1 = vec2(1.00000, 1.00000);
	vec2 n_out10p0 = n_out13p0 * n_in10p1 + n_out14p0;


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p1 = n_out4p0.r;


// FloatParameter:31
	float n_out31p0 = LOD_min;


// FloatParameter:32
	float n_out32p0 = LOD_max;


	float n_out5p0;
// Remap:5
	float n_in5p1 = 0.00000;
	float n_in5p2 = 1.00000;
	{
		float __input_range = n_in5p2 - n_in5p1;
		float __output_range = n_out32p0 - n_out31p0;
		n_out5p0 = n_out31p0 + __output_range * ((n_out4p1 - n_in5p1) / __input_range);
	}


	vec4 n_out7p0;
// Texture2D:7
	n_out7p0 = textureLod(smoke_texture, n_out10p0, n_out5p0);
	float n_out7p1 = n_out7p0.r;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(smake_mask, UV);
	float n_out9p1 = n_out9p0.r;


// FloatOp:16
	float n_out16p0 = n_out7p1 * n_out9p1;


// Input:28
	vec4 n_out28p0 = COLOR;
	float n_out28p4 = n_out28p0.a;


// FloatOp:27
	float n_out27p0 = n_out16p0 * n_out28p4;


// BooleanParameter:34
	bool n_out34p0 = Enable_Proximity_Fade;


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


	float n_out33p0;
// Switch:33
	float n_in33p2 = 1.00000;
	n_out33p0 = mix(n_in33p2, n_out25p0, float(n_out34p0));


// FloatOp:26
	float n_out26p0 = n_out27p0 * n_out33p0;


// Output:0
	ALBEDO = vec3(n_out30p0.xyz);
	ALPHA = n_out26p0;



vec3 sleep_local = (sleep_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
float sleep_edge = 1.0 - smoothstep(sleep_radius_units * 0.78, sleep_radius_units, length(sleep_local.xz));
float sleep_height = 1.0 - smoothstep(1.35, 1.75, sleep_local.y);
ALPHA *= sleep_opacity * sleep_edge * sleep_height;
}



