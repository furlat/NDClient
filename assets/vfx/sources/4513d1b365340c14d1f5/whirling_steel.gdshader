shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
uniform sampler2D source_albedo : source_color, filter_linear_mipmap;
uniform float field_clock = 0.0;
uniform float field_opacity = 0.0;
void fragment() {
	vec3 steel = texture(source_albedo, UV).rgb;
	vec3 world_normal = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float directional = .25 + .75 * abs(dot(world_normal, normalize(vec3(.4,.8,.3))));
	float detail = .6 + .4 * clamp(dot(steel,vec3(.2126,.7152,.0722))*2.0,0.0,1.0);
	ALBEDO = mix(vec3(.055,.10,.15),vec3(.48,.62,.70),directional) * detail;
	ALPHA = field_opacity;
}
