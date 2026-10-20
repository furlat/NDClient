shader_type spatial;
uniform sampler2D factory_liquid_field_texture : filter_nearest, repeat_disable;
vec4 factory_liquid_field(int index) { return texelFetch(factory_liquid_field_texture,ivec2(index,0),0); }

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 gpu_drop_colour : source_color = vec4(1.);
void vertex() {
	vec3 point = factory_liquid_field(INSTANCE_ID).xyz;
	VERTEX = VERTEX * float(point.y >= .03) + point;
}
void fragment() {
	ALBEDO = gpu_drop_colour.rgb;
	ROUGHNESS = .25;
	SPECULAR = .5;
}


