shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_fire_owner_seconds=0.0;

uniform float fire_owner_seconds=0.0;
uniform float fire_owner_alpha=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform sampler2D Texture : source_color, repeat_disable;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform vec2 Erosion_Scale = vec2(1.000000, 1.000000);
uniform vec2 Erosion_Speed = vec2(0.000000, 0.000000);
uniform sampler2D substract_mask : source_color, hint_default_black, repeat_enable;



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
// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out15p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out21p0;
// Texture2D:21
	n_out21p0 = texture(Color_1D_Gradient, vec2(n_out10p1));
	float n_out21p4 = n_out21p0.a;


// Input:33
	vec4 n_out33p0 = COLOR;


// VectorOp:23
	vec3 n_out23p0 = vec3(n_out21p0.xyz) * vec3(n_out33p0.xyz);


// Input:26
	vec4 n_out26p0 = COLOR;
	float n_out26p4 = n_out26p0.a;


// Vector2Parameter:28
	vec2 n_out28p0 = Erosion_Scale;


// UVFunc:27
	vec2 n_in27p2 = vec2(0.00000, 0.00000);
	vec2 n_out27p0 = (UV - n_in27p2) * n_out28p0 + n_in27p2;


// Vector2Parameter:29
	vec2 n_out29p0 = Erosion_Speed;


// Input:31
	float n_out31p0 = (vfx_package_seconds()+vfx_package_offset_fire_owner_seconds);


// VectorOp:32
	vec2 n_out32p0 = n_out29p0 * vec2(n_out31p0);


// UVFunc:30
	vec2 n_in30p1 = vec2(1.00000, 1.00000);
	vec2 n_out30p0 = n_out32p0 * n_in30p1 + n_out27p0;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(substract_mask, n_out30p0);
	float n_out18p1 = n_out18p0.r;


// FloatOp:19
	float n_out19p0 = n_out21p4 - n_out18p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out19p0, n_in25p1, n_in25p2);


// SmoothStep:34
	float n_in34p0 = 0.00000;
	float n_out34p0 = smoothstep(n_in34p0, n_out26p4, n_out25p0);


// Output:0
	ALBEDO = n_out23p0;
	ALPHA = n_out34p0;



ALBEDO*=0.32;
EMISSION*=0.32;
ALPHA*=fire_owner_alpha;
}


