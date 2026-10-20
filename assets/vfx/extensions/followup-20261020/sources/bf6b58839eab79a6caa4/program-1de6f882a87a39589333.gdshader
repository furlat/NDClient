shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform vec4 Color : source_color;
uniform float Fresnel = 8.0;



void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// ColorParameter:3
	vec4 n_out3p0 = Color;


// FloatParameter:4
	float n_out4p0 = Fresnel;


// Fresnel:2
	float n_out2p0 = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out4p0);


// Output:0
	ALBEDO = vec3(n_out3p0.xyz);
	ALPHA = n_out2p0;



ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}







