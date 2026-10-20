shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, fog_disabled;

uniform sampler2D Linear_Color_1D : source_color, filter_linear;
uniform sampler2D curve_frg_16 : repeat_disable;
uniform sampler2D Alpha_Texture : source_color, filter_linear;
uniform float ProximityFade = 0.5;
uniform sampler2D depth_tex_frg_6 : hint_depth_texture;
uniform sampler2D Emission_color_1D : source_color, filter_linear;



void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p1 = n_out4p0.r;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Linear_Color_1D, vec2(n_out4p4));
	float n_out19p4 = n_out19p0.a;


// Input:13
	vec2 n_out13p0 = UV;


// CurveTexture:16
	float n_out16p0 = texture(curve_frg_16, vec2(n_out4p1)).r;


// VectorCompose:15
	float n_in15p1 = 0.00000;
	vec2 n_out15p0 = vec2(n_out16p0, n_in15p1);


// MultiplyAdd:14
	vec2 n_in14p1 = vec2(0.50000, 1.00000);
	vec2 n_out14p0 = fma(n_out13p0, n_in14p1, n_out15p0);


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Alpha_Texture, n_out14p0);
	float n_out3p1 = n_out3p0.r;


// FloatOp:8
	float n_out8p0 = n_out4p4 * n_out3p1;


// FloatOp:22
	float n_out22p0 = n_out19p4 * n_out8p0;


// FloatParameter:7
	float n_out7p0 = ProximityFade;


	float n_out6p0;
// ProximityFade:6
	{
		float __depth_tex = texture(depth_tex_frg_6, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out6p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out7p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:5
	float n_out5p0 = n_out22p0 * n_out6p0;


	vec4 n_out21p0;
// Texture2D:21
	n_out21p0 = texture(Emission_color_1D, vec2(n_out4p4));


// Output:0
	ALBEDO = vec3(n_out19p0.xyz);
	ALPHA = n_out5p0;
	EMISSION = vec3(n_out21p0.xyz);


}

