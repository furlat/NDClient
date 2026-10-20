shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform float Intensity = 1.0;
uniform bool EnableBlinkin = false;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Texture : source_color, repeat_enable;
uniform sampler2D Add_Texture : source_color, hint_default_black, filter_linear;
uniform sampler2D Multiply_Texture : source_color, filter_linear;
uniform float Blinking_speed = 0.0;
uniform float min_brightness = 0.5;
uniform float max_brightness2 = 1.0;
uniform sampler2D Color_gradient_1D : source_color, repeat_disable;
uniform bool Enable_Proximity_Fade = true;
uniform float Proximity_Fade = 0.10000000149012;
uniform sampler2D depth_tex_frg_32 : hint_depth_texture;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;



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
// FloatParameter:30
	float n_out30p0 = Intensity;


// BooleanParameter:26
	bool n_out26p0 = EnableBlinkin;


// Vector2Parameter:5
	vec2 n_out5p0 = Scale;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (UV - n_in4p2) * n_out5p0 + n_in4p2;


// Input:10
	float n_out10p0 = support_clock;


// Vector2Parameter:12
	vec2 n_out12p0 = Velocity;


// VectorOp:11
	vec2 n_out11p0 = vec2(n_out10p0) * n_out12p0;


// UVFunc:9
	vec2 n_in9p1 = vec2(1.00000, 1.00000);
	vec2 n_out9p0 = n_out11p0 * n_in9p1 + n_out4p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture, n_out9p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Add_Texture, UV);
	float n_out15p1 = n_out15p0.r;


// FloatOp:16
	float n_out16p0 = n_out3p1 + n_out15p1;


	vec4 n_out7p0;
// Texture2D:7
	n_out7p0 = texture(Multiply_Texture, UV);
	float n_out7p1 = n_out7p0.r;


// FloatOp:8
	float n_out8p0 = n_out16p0 * n_out7p1;


// Clamp:13
	float n_in13p1 = 0.00000;
	float n_in13p2 = 1.00000;
	float n_out13p0 = clamp(n_out8p0, n_in13p1, n_in13p2);


// Input:17
	float n_out17p0 = support_clock;


// FloatParameter:19
	float n_out19p0 = Blinking_speed;


// FloatOp:18
	float n_out18p0 = n_out17p0 * n_out19p0;


// FloatFunc:20
	float n_out20p0 = cos(n_out18p0);


// FloatParameter:22
	float n_out22p0 = min_brightness;


// FloatParameter:23
	float n_out23p0 = max_brightness2;


	float n_out21p0;
// Remap:21
	float n_in21p1 = -1.00000;
	float n_in21p2 = 1.00000;
	{
		float __input_range = n_in21p2 - n_in21p1;
		float __output_range = n_out23p0 - n_out22p0;
		n_out21p0 = n_out22p0 + __output_range * ((n_out20p0 - n_in21p1) / __input_range);
	}


// FloatOp:24
	float n_out24p0 = n_out13p0 * n_out21p0;


	float n_out25p0;
// Switch:25
	n_out25p0 = mix(n_out13p0, n_out24p0, float(n_out26p0));


	vec4 n_out28p0;
// Texture2D:28
	n_out28p0 = texture(Color_gradient_1D, vec2(n_out25p0));
	float n_out28p4 = n_out28p0.a;


// VectorOp:31
	vec3 n_out31p0 = vec3(n_out30p0) * vec3(n_out28p0.xyz);


// BooleanParameter:36
	bool n_out36p0 = Enable_Proximity_Fade;


// FloatParameter:34
	float n_out34p0 = Proximity_Fade;


	float n_out32p0;
// ProximityFade:32
	{
		float __depth_tex = texture(depth_tex_frg_32, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out32p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out34p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:33
	float n_out33p0 = n_out28p4 * n_out32p0;


	float n_out35p0;
// Switch:35
	n_out35p0 = mix(n_out28p4, n_out33p0, float(n_out36p0));


// FloatParameter:38
	float n_out38p0 = Opacity;


// FloatOp:37
	float n_out37p0 = n_out35p0 * n_out38p0;


// Output:0
	ALBEDO = n_out31p0;
	ALPHA = n_out37p0;



ALPHA *= support_envelope;
}






