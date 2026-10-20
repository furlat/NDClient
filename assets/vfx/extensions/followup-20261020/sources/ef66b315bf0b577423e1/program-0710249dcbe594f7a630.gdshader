shader_type spatial;uniform float fx_clock=0.;uniform float opacity=1.;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform sampler2D Texture : source_color, repeat_disable;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out15p0);
	float n_out10p1 = n_out10p0.r;


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
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out11p0;


float v=max(ALBEDO.r,max(ALBEDO.g,ALBEDO.b));ALBEDO=mix(vec3(.48,.025,.003),vec3(.98,.28,.012),clamp(v,0.,1.));ALPHA*=smoothstep(.018,.08,v);ALPHA*=opacity;}



