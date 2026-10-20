shader_type spatial;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec2 Distortion_Speed_xy = vec2(0.000000, 0.000000);
uniform sampler2D Distortioner_Texture : source_color, filter_linear;
uniform float Distortion_Div = 10.0;
uniform sampler2D Texture : source_color, repeat_disable;
uniform sampler2D Gradient_1D_texture : source_color, filter_linear;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;



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
// Input:26
	vec2 n_out26p0 = UV;


// Input:31
	float n_out31p0 = source_clock;


// Vector2Parameter:33
	vec2 n_out33p0 = Distortion_Speed_xy;


// VectorOp:32
	vec2 n_out32p0 = vec2(n_out31p0) * n_out33p0;


// UVFunc:28
	vec2 n_in28p1 = vec2(1.00000, 1.00000);
	vec2 n_out28p0 = n_out32p0 * n_in28p1 + UV;


	vec4 n_out25p0;
// Texture2D:25
	n_out25p0 = texture(Distortioner_Texture, n_out28p0);
	float n_out25p1 = n_out25p0.r;


// FloatParameter:30
	float n_out30p0 = Distortion_Div;


// FloatOp:29
	float n_out29p0 = n_out25p1 / n_out30p0;


// VectorOp:27
	vec2 n_out27p0 = n_out26p0 + vec2(n_out29p0);


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out27p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Gradient_1D_texture, vec2(n_out10p1));


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p1 = n_out4p0.r;
	float n_out4p4 = n_out4p0.a;


// VectorOp:35
	vec3 n_out35p0 = vec3(n_out18p0.xyz) * vec3(n_out4p1);


// FloatOp:34
	float n_out34p0 = n_out4p4 * n_out10p1;


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
	float n_out11p0 = n_out34p0 * n_out12p0;


// Output:0
	ALBEDO = n_out35p0;
	ALPHA = n_out11p0;


}



