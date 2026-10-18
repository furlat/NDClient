shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 gpu_fluid[160];
uniform vec4 gpu_drop_colour : source_color = vec4(1.);
void vertex() {
	vec3 point = gpu_fluid[INSTANCE_ID].xyz;
	VERTEX = VERTEX * float(point.y >= .03) + point;
}
void fragment() {
	ALBEDO = gpu_drop_colour.rgb;
	ROUGHNESS = .25;
	SPECULAR = .5;
}
