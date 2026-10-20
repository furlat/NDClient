shader_type spatial;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec4 Line_Color : source_color;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform sampler2D Texture : source_color, repeat_disable;
uniform sampler2D Gradient_1D_texture : source_color, filter_linear;
uniform float Line_Thickness = 0.0;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// ColorParameter:22
	vec4 n_out22p0 = Line_Color;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out15p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Gradient_1D_texture, vec2(n_out10p1));


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// FloatParameter:23
	float n_out23p0 = Line_Thickness;


// FloatOp:20
	float n_out20p0 = n_out4p4 + n_out23p0;


// Step:19
	float n_out19p0 = step(n_out20p0, n_out10p1);


// Mix:21
	vec3 n_out21p0 = mix(vec3(n_out22p0.xyz), vec3(n_out18p0.xyz), n_out19p0);


// Step:14
	float n_out14p0 = step(n_out4p4, n_out10p1);


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
	float n_out11p0 = n_out14p0 * n_out12p0;


// Output:0
	ALBEDO = n_out21p0;
	ALPHA = n_out11p0;


}


