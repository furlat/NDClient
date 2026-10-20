shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_fire_owner_seconds=0.0;

uniform float fire_owner_seconds=0.0;
uniform float fire_owner_alpha=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_noise : source_color, repeat_enable;
uniform bool Fresnel_Invert = false;
uniform float Fresnel_power = 1.0;
uniform sampler2D Gradient_Color_1D : source_color, repeat_disable;
uniform float Color_Intensity = 1.0;



void fragment() {
// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:11
	vec2 n_out11p0 = Speed_XY;


// Input:10
	float n_out10p0 = (vfx_package_seconds()+vfx_package_offset_fire_owner_seconds);


// VectorOp:12
	vec2 n_out12p0 = n_out11p0 * vec2(n_out10p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out12p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_noise, n_out8p0);
	float n_out3p1 = n_out3p0.r;


// BooleanParameter:23
	bool n_out23p0 = Fresnel_Invert;


// FloatParameter:22
	float n_out22p0 = Fresnel_power;


// Fresnel:21
	float n_out21p0 = n_out23p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0));


// FloatOp:14
	float n_out14p0 = n_out3p1 + n_out21p0;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Gradient_Color_1D, vec2(n_out14p0));
	float n_out18p4 = n_out18p0.a;


// FloatParameter:20
	float n_out20p0 = Color_Intensity;


// VectorOp:19
	vec3 n_out19p0 = vec3(n_out18p0.xyz) * vec3(n_out20p0);


// Output:0
	ALBEDO = n_out19p0;
	ALPHA = n_out18p4;



ALBEDO*=0.11;
EMISSION*=0.11;
ALPHA*=fire_owner_alpha;
}


