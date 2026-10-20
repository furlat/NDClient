shader_type spatial;
varying float repair_mesh_height;
uniform sampler2D repair_native_noise : source_color;
uniform vec2 repair_native_scale=vec2(3.0);
uniform vec2 repair_native_speed=vec2(0.0,3.0);

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform float Color_Intensity = 1.0;
uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_Texture : source_color;
uniform sampler2D Add_Texture : source_color, repeat_disable;
uniform sampler2D Substract_Texture : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_1D_Color : source_color;
uniform float Dissolver_edge : hint_range(0.0, 1.0) = 0.0;



void fragment() {

// FloatParameter:27
	float n_out27p0 = Color_Intensity;


// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:10
	vec2 n_out10p0 = Speed_XY;


// Input:12
	float n_out12p0 = support_clock;


// VectorOp:11
	vec2 n_out11p0 = n_out10p0 * vec2(n_out12p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out11p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_Texture, n_out8p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out6p0;
// Texture2D:6
	n_out6p0 = texture(Add_Texture, UV);
	float n_out6p1 = n_out6p0.r;


// FloatOp:24
	float n_out24p0 = n_out3p1 + n_out6p1;


	vec4 n_out30p0;
// Texture2D:30
	n_out30p0 = texture(Substract_Texture, UV);
	float n_out30p1 = n_out30p0.r;


// FloatOp:32
	float n_out32p0 = n_out24p0 - n_out30p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out32p0, n_in25p1, n_in25p2);


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Gradient_1D_Color, vec2(n_out25p0));
	float n_out15p4 = n_out15p0.a;


// VectorOp:26
	vec3 n_out26p0 = vec3(n_out27p0) * vec3(n_out15p0.xyz);


// FloatParameter:29
	float n_out29p0 = Dissolver_edge;


// SmoothStep:28
	float n_in28p1 = 1.00000;
	float n_out28p0 = smoothstep(n_out29p0, n_in28p1, n_out15p4);


// Output:0
	ALBEDO = n_out26p0;
	ALPHA = n_out28p0;



ALPHA *= support_envelope;

float repair_noise=texture(repair_native_noise,UV*repair_native_scale+repair_native_speed*support_clock).r;
float repair_tip=1.0-smoothstep(0.74+0.22*repair_noise,0.995,repair_mesh_height);
ALPHA*=smoothstep(0.10,0.50,repair_noise)*repair_tip;

ALPHA*=0.12;
}


void vertex(){repair_mesh_height=VERTEX.y;}



