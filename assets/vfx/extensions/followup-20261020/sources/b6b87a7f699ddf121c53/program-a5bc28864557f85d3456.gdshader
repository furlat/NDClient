shader_type spatial; uniform float factory_layer_coverage=1.0;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, ambient_light_disabled, debug_shadow_splits, fog_disabled;

uniform vec4 Color2 : source_color;
uniform vec4 Color1 : source_color;
uniform sampler2D Mask_Texture : source_color, filter_linear;



void fragment() {
// ColorParameter:7
	vec4 n_out7p0 = Color2;
	float n_out7p4 = n_out7p0.a;


// ColorParameter:6
	vec4 n_out6p0 = Color1;
	float n_out6p4 = n_out6p0.a;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Mask_Texture, UV);
	float n_out9p1 = n_out9p0.r;


// Mix:10
	vec3 n_out10p0 = mix(vec3(n_out7p0.xyz), vec3(n_out6p0.xyz), n_out9p1);


// Mix:11
	float n_out11p0 = mix(n_out7p4, n_out6p4, n_out9p1);


// Output:0
	ALBEDO = n_out10p0;
	ALPHA = n_out11p0;



ALPHA *= factory_layer_coverage;
vec2 coverage_edge=min(UV,vec2(1.0)-UV);ALPHA*=smoothstep(0.0,0.06,min(coverage_edge.x,coverage_edge.y));
}



