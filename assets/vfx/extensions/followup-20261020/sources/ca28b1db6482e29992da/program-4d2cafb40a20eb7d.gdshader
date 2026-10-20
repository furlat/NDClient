shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D Alpha_Texture : source_color, filter_linear;
uniform float ProximityFade = 0.5;
uniform sampler2D depth_tex_frg_6 : hint_depth_texture;



void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Alpha_Texture, UV);
	float n_out3p1 = n_out3p0.r;


// FloatOp:8
	float n_out8p0 = n_out4p4 * n_out3p1;


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
	float n_out5p0 = n_out8p0 * n_out6p0;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out5p0;


}

