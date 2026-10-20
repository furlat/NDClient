shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_fireball_detail_age=0.0;
uniform float vfx_package_offset_fireball_detail_thin_start_seconds=0.0;
uniform float vfx_package_offset_fireball_detail_thin_end_seconds=0.0;
uniform float vfx_package_offset_fireball_detail_clear_start_seconds=0.0;
uniform float vfx_package_offset_fireball_detail_clear_end_seconds=0.0;
uniform float vfx_package_offset_source_clock=0.0;


uniform float fireball_detail_age = 0.0;
uniform float fireball_detail_flow_scale;
uniform float fireball_detail_fine_scale;
uniform float fireball_detail_flow_motion;
uniform float fireball_detail_fine_motion;
uniform float fireball_detail_fine_weight;
uniform float fireball_detail_noise_low;
uniform float fireball_detail_noise_high;
uniform float fireball_detail_albedo_low;
uniform float fireball_detail_albedo_high;
uniform float fireball_detail_emission_low;
uniform float fireball_detail_emission_high;
uniform float fireball_detail_porosity_floor;
uniform float fireball_detail_peak_opacity;
uniform float fireball_detail_tail_opacity;
uniform float fireball_detail_thin_start_seconds;
uniform float fireball_detail_thin_end_seconds;
uniform float fireball_detail_clear_start_seconds;
uniform float fireball_detail_clear_end_seconds;

uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Displacement_Speed;
uniform sampler2D Dissplacement_texture : source_color, filter_linear;
uniform sampler2D Dark_Color_Gradient_1D : source_color, filter_linear;
uniform sampler2D Disapear_Noise : source_color, filter_linear;
uniform sampler2D Gradient_1D : source_color, hint_default_black, repeat_disable;
uniform float ProximityFade = 0.5;
uniform sampler2D depth_tex_frg_47 : hint_depth_texture;
uniform sampler2D Emission_Gradient_1D : source_color, filter_linear;
uniform float Hard_Shadow_min = 0.0;
uniform float Hard_Shadow_max = 0.10000000149012;
uniform float Shadow_Min = 0.10000000149012;
uniform float Shadow_Max = 1.0;



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:4
	vec3 n_out4p0 = NORMAL;


// Input:16
	vec4 n_out16p0 = COLOR;
	float n_out16p2 = n_out16p0.g;


// Input:13
	float n_out13p0 = (vfx_package_seconds()+vfx_package_offset_source_clock);


// Vector2Parameter:15
	vec2 n_out15p0 = Displacement_Speed;


// VectorOp:14
	vec2 n_out14p0 = vec2(n_out13p0) * n_out15p0;


// UVFunc:12
	vec2 n_in12p1 = vec2(1.00000, 1.00000);
	vec2 n_out12p0 = n_out14p0 * n_in12p1 + UV;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Dissplacement_texture, n_out12p0);
	float n_out11p1 = n_out11p0.r;


// FloatFunc:8
	float n_out8p0 = 1.0 - n_out11p1;


// FloatOp:9
	float n_out9p0 = n_out16p2 * n_out8p0;


// VectorOp:5
	vec3 n_out5p0 = n_out4p0 * vec3(n_out9p0);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
// Input:54
	vec4 n_out54p0 = COLOR;
	float n_out54p1 = n_out54p0.r;


	vec4 n_out45p0;
// Texture2D:45
	n_out45p0 = texture(Dark_Color_Gradient_1D, vec2(n_out54p1));


// Input:33
	vec4 n_out33p0 = COLOR;
	float n_out33p4 = n_out33p0.a;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Disapear_Noise, UV);
	float n_out38p1 = n_out38p0.r;


// SmoothStep:20
	float n_in20p1 = 1.00000;
	float n_out20p0 = smoothstep(n_out33p4, n_in20p1, n_out38p1);


	vec4 n_out29p0;
// Texture2D:29
	n_out29p0 = texture(Gradient_1D, vec2(n_out20p0));
	float n_out29p1 = n_out29p0.r;


// FloatParameter:48
	float n_out48p0 = ProximityFade;


	float n_out47p0;
// ProximityFade:47
	{
		float __depth_tex = texture(depth_tex_frg_47, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out47p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out48p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:46
	float n_out46p0 = n_out29p1 * n_out47p0;


// Input:36
	vec4 n_out36p0 = COLOR;
	float n_out36p1 = n_out36p0.r;


	vec4 n_out50p0;
// Texture2D:50
	n_out50p0 = texture(Emission_Gradient_1D, vec2(n_out36p1));


// Output:0
	ALBEDO = vec3(n_out45p0.xyz);
	ALPHA = n_out46p0;
	EMISSION = vec3(n_out50p0.xyz);



// Original HDR layer soft knee before unchanged accepted palette; original ALPHA is untouched.

float repair_native_flow=texture(Dissplacement_texture,UV+(vfx_package_seconds()+vfx_package_offset_source_clock)*Displacement_Speed).r;
float repair_native_temperature=clamp(COLOR.r+(repair_native_flow-0.5)*0.70,0.0,1.0);
ALBEDO=texture(Dark_Color_Gradient_1D,vec2(repair_native_temperature)).rgb;
EMISSION=texture(Emission_Gradient_1D,vec2(repair_native_temperature)).rgb;
vec3 repair_energy=max(ALBEDO+EMISSION,vec3(0.0));
float repair_gain=0.72/(1.0+max(max(repair_energy.r,repair_energy.g),repair_energy.b));
ALBEDO*=repair_gain; EMISSION*=repair_gain;

// Same source texture, on the source surface: no screen-space wash or new mesh.
vec2 fireball_detail_drift = (vfx_package_seconds()+vfx_package_offset_fireball_detail_age) * Displacement_Speed;
float fireball_detail_coarse = texture(Dissplacement_texture, UV * fireball_detail_flow_scale + fireball_detail_drift * fireball_detail_flow_motion).r;
float fireball_detail_fine = texture(Dissplacement_texture, UV * fireball_detail_fine_scale - fireball_detail_drift.yx * fireball_detail_fine_motion).r;
float fireball_detail_heat = smoothstep(fireball_detail_noise_low, fireball_detail_noise_high, mix(fireball_detail_coarse, fireball_detail_fine, fireball_detail_fine_weight));
ALBEDO *= mix(fireball_detail_albedo_low, fireball_detail_albedo_high, fireball_detail_heat);
EMISSION *= mix(fireball_detail_emission_low, fireball_detail_emission_high, smoothstep(0.20, 0.85, fireball_detail_heat));
ALPHA *= mix(fireball_detail_porosity_floor, 1.0, smoothstep(0.12, 0.75, fireball_detail_heat));

float fireball_detail_thin = smoothstep((vfx_package_seconds()+vfx_package_offset_fireball_detail_thin_start_seconds), (vfx_package_seconds()+vfx_package_offset_fireball_detail_thin_end_seconds), (vfx_package_seconds()+vfx_package_offset_fireball_detail_age));
float fireball_detail_clear = 1.0 - smoothstep((vfx_package_seconds()+vfx_package_offset_fireball_detail_clear_start_seconds), (vfx_package_seconds()+vfx_package_offset_fireball_detail_clear_end_seconds), (vfx_package_seconds()+vfx_package_offset_fireball_detail_age));
ALPHA *= mix(fireball_detail_peak_opacity, fireball_detail_tail_opacity, fireball_detail_thin) * fireball_detail_clear;
}

void light() {
// FloatParameter:5
	float n_out5p0 = Hard_Shadow_min;


// FloatParameter:6
	float n_out6p0 = Hard_Shadow_max;


// Input:2
	vec3 n_out2p0 = NORMAL;


// Input:11
	vec3 n_out11p0 = LIGHT;


// DotProduct:3
	float n_out3p0 = dot(n_out2p0, n_out11p0);


// Fresnel:10
	float n_in10p3 = 10.00000;
	float n_out10p0 = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_in10p3);


// FloatOp:12
	float n_out12p0 = n_out3p0 + n_out10p0;


// SmoothStep:4
	vec3 n_out4p0 = smoothstep(vec3(n_out5p0), vec3(n_out6p0), vec3(n_out12p0));


// FloatParameter:7
	float n_out7p0 = Shadow_Min;


// FloatParameter:9
	float n_out9p0 = Shadow_Max;


// Clamp:8
	vec3 n_out8p0 = clamp(n_out4p0, vec3(n_out7p0), vec3(n_out9p0));


// Output:0
	DIFFUSE_LIGHT = n_out8p0;


}


