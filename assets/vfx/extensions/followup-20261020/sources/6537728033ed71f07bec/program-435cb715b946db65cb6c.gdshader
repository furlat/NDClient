shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec4 Color : source_color;
uniform bool Use_Proximity_Fade;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Offset = vec2(0.000000, 0.000000);
uniform sampler2D Texture : source_color, repeat_disable;
uniform sampler2D Texture_Add : source_color, hint_default_black, repeat_enable;
uniform float Blinking_speed = 0.0;
uniform float min_brightness = 0.5;
uniform float max_brightness2 = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_23 : hint_depth_texture;



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
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// ColorParameter:10
	vec4 n_out10p0 = Color;


// BooleanParameter:26
	bool n_out26p0 = Use_Proximity_Fade;


// Vector2Parameter:5
	vec2 n_out5p0 = Scale;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (UV - n_in4p2) * n_out5p0 + n_in4p2;


// Vector2Parameter:9
	vec2 n_out9p0 = Offset;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out4p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture, n_out6p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out29p0;
// Texture2D:29
	n_out29p0 = texture(Texture_Add, UV);
	float n_out29p1 = n_out29p0.r;


// FloatOp:27
	float n_out27p0 = n_out3p1 + n_out29p1;


// Input:13
	float n_out13p0 = support_clock;


// FloatParameter:15
	float n_out15p0 = Blinking_speed;


// FloatOp:14
	float n_out14p0 = n_out13p0 * n_out15p0;


// FloatFunc:16
	float n_out16p0 = cos(n_out14p0);


// FloatParameter:20
	float n_out20p0 = min_brightness;


// FloatParameter:21
	float n_out21p0 = max_brightness2;


	float n_out17p0;
// Remap:17
	float n_in17p1 = -1.00000;
	float n_in17p2 = 1.00000;
	{
		float __input_range = n_in17p2 - n_in17p1;
		float __output_range = n_out21p0 - n_out20p0;
		n_out17p0 = n_out20p0 + __output_range * ((n_out16p0 - n_in17p1) / __input_range);
	}


// FloatOp:19
	float n_out19p0 = n_out27p0 * n_out17p0;


// FloatParameter:32
	float n_out32p0 = opacity;


// FloatOp:31
	float n_out31p0 = n_out19p0 * n_out32p0;


// Clamp:33
	float n_in33p1 = 0.00000;
	float n_in33p2 = 1.00000;
	float n_out33p0 = clamp(n_out31p0, n_in33p1, n_in33p2);


// FloatParameter:24
	float n_out24p0 = Proximity_Fade;


	float n_out23p0;
// ProximityFade:23
	{
		float __depth_tex = texture(depth_tex_frg_23, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out23p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out24p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:22
	float n_out22p0 = n_out33p0 * n_out23p0;


	float n_out25p0;
// Switch:25
	n_out25p0 = mix(n_out33p0, n_out22p0, float(n_out26p0));


// Output:0
	ALBEDO = vec3(n_out10p0.xyz);
	ALPHA = n_out25p0;



ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}





