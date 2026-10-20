shader_type particles;
render_mode disable_force, disable_velocity;
uniform sampler2D native_instance_transforms : filter_nearest, repeat_disable;
uniform sampler2D plant_cell_states : filter_nearest, repeat_disable;

void process() {
	int index = int(INDEX);
	vec4 x = texelFetch(native_instance_transforms, ivec2(0, index), 0);
	vec4 y = texelFetch(native_instance_transforms, ivec2(1, index), 0);
	vec4 z = texelFetch(native_instance_transforms, ivec2(2, index), 0);
	vec4 origin = texelFetch(native_instance_transforms, ivec2(3, index), 0);
	vec4 state = texelFetch(plant_cell_states, ivec2(int(origin.w), 0), 0);
	// Every original pivot rotates only around Y. Its animated Y scale can
	// therefore multiply this exact source transform's Y row about y=.025.
	x.y *= state.x;
	y.y *= state.x;
	z.y *= state.x;
	origin.y = .025 + state.x * x.w;
	TRANSFORM = mat4(vec4(x.xyz, 0.), vec4(y.xyz, 0.), vec4(z.xyz, 0.), vec4(origin.xyz, 1.));
	CUSTOM = vec4(state.yzw, origin.w);
	COLOR = vec4(1.);
	VELOCITY = vec3(0.);
	ACTIVE = true;
}
