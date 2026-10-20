shader_type spatial; uniform float factory_layer_coverage=1.0;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Mask_Texture : source_color, filter_linear;



void fragment() {
// Input:10
	vec4 n_out10p0 = COLOR;
	float n_out10p4 = n_out10p0.a;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Mask_Texture, UV);
	float n_out9p1 = n_out9p0.r;


// FloatOp:11
	float n_out11p0 = n_out10p4 * n_out9p1;


// Output:0
	ALBEDO = vec3(n_out10p0.xyz);
	ALPHA = n_out11p0;



ALPHA *= factory_layer_coverage;
vec2 coverage_edge=min(UV,vec2(1.0)-UV);ALPHA*=smoothstep(0.0,0.06,min(coverage_edge.x,coverage_edge.y));
}



