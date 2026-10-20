shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_delivery_clock=0.0;

uniform float delivery_clock=0.;
uniform float delivery_envelope=0.;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec2 Fire_Scale = vec2(3.000000, 2.000000);
uniform vec2 Fire_Speed = vec2(0.100000, 2.000000);
uniform sampler2D Fire_Texture : source_color, repeat_enable;
uniform sampler2D Gradient_Substract : source_color, filter_linear, repeat_enable;
uniform float Color_Dissipation = 1.0;
uniform sampler2D Color_1D_Gradient : source_color, filter_linear, repeat_enable;
uniform float Dissapear_Step = 0.00999999977648;
uniform float Proximity_Fade = 0.20000000298023;
uniform sampler2D depth_tex_frg_50 : hint_depth_texture;



void fragment() {
// Vector2Parameter:38
	vec2 n_out38p0 = Fire_Scale;


// UVFunc:21
	vec2 n_in21p2 = vec2(0.00000, 0.00000);
	vec2 n_out21p0 = (UV - n_in21p2) * n_out38p0 + n_in21p2;


// Input:13
	float n_out13p0 = (vfx_package_seconds()+vfx_package_offset_delivery_clock);


// Vector2Parameter:39
	vec2 n_out39p0 = Fire_Speed;


// VectorOp:15
	vec2 n_out15p0 = vec2(n_out13p0) * n_out39p0;


// UVFunc:16
	vec2 n_in16p1 = vec2(1.00000, 1.00000);
	vec2 n_out16p0 = n_out15p0 * n_in16p1 + n_out21p0;


	vec4 n_out44p0;
// Texture2D:44
	n_out44p0 = texture(Fire_Texture, n_out16p0);
	float n_out44p1 = n_out44p0.r;


	vec4 n_out54p0;
// Texture2D:54
	n_out54p0 = texture(Gradient_Substract, UV);
	float n_out54p1 = n_out54p0.r;


// FloatOp:23
	float n_out23p0 = n_out44p1 - n_out54p1;


// FloatParameter:56
	float n_out56p0 = Color_Dissipation;


// FloatOp:55
	float n_out55p0 = pow(n_out23p0, n_out56p0);


	vec4 n_out58p0;
// Texture2D:58
	n_out58p0 = texture(Color_1D_Gradient, vec2(n_out55p0));
	float n_out58p4 = n_out58p0.a;


// FloatParameter:47
	float n_out47p0 = Dissapear_Step;


// Step:59
	float n_out59p0 = step(n_out47p0, n_out23p0);


// FloatParameter:51
	float n_out51p0 = Proximity_Fade;


	float n_out50p0;
// ProximityFade:50
	{
		float __depth_tex = texture(depth_tex_frg_50, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out50p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out51p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:49
	float n_out49p0 = n_out59p0 * n_out50p0;


// FloatOp:60
	float n_out60p0 = n_out58p4 * n_out49p0;


// Clamp:41
	float n_in41p1 = 0.00000;
	float n_in41p2 = 1.00000;
	float n_out41p0 = clamp(n_out60p0, n_in41p1, n_in41p2);


// Output:0
	ALBEDO = vec3(n_out58p0.xyz);
	ALPHA = n_out41p0;



ALPHA *= delivery_envelope;
}



