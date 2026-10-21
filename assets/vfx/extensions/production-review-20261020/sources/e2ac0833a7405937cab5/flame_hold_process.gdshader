shader_type particles;
// Explicit new artwork loop from the actual source hold interval. The native
// draw shader keeps its separate absolute owner clock; no gameplay age resets.
render_mode disable_force, disable_velocity, keep_data;
uniform sampler2D hold_data: filter_nearest, repeat_disable;
uniform float hold_cursor = 0.0;
uniform float half_phase = 0.0;
uniform float hold_period = 2.0;

vec4 hold_value(int frame, int row) {
	return texelFetch(hold_data, ivec2(frame, row), 0);
}

void start() {
	TRANSFORM = mat4(0.0);
	COLOR = vec4(0.0);
}

void process() {
	float phase = mod(hold_cursor + half_phase, hold_period) / hold_period;
	float frame = phase * float(textureSize(hold_data, 0).x - 1);
	int first = int(floor(frame));
	int second = min(first + 1, textureSize(hold_data, 0).x - 1);
	float blend = fract(frame);
	int row = int(INDEX) * 6;
	float alive_first = hold_value(first, row + 5).x;
	float alive_second = hold_value(second, row + 5).x;
	if (alive_first != alive_second) {
		blend = step(0.5, blend);
	}
	vec4 x = mix(hold_value(first, row), hold_value(second, row), blend);
	vec4 y = mix(hold_value(first, row + 1), hold_value(second, row + 1), blend);
	vec4 z = mix(hold_value(first, row + 2), hold_value(second, row + 2), blend);
	TRANSFORM = mat4(vec4(x.xyz, 0.0), vec4(y.xyz, 0.0), vec4(z.xyz, 0.0), vec4(x.w, y.w, z.w, 1.0));
	COLOR = mix(hold_value(first, row + 3), hold_value(second, row + 3), blend);
	CUSTOM = mix(hold_value(first, row + 4), hold_value(second, row + 4), blend);
	float alive = mix(alive_first, alive_second, blend);
	COLOR.a *= alive * (0.5 - 0.5 * cos(6.28318530718 * phase));
	VELOCITY = vec3(0.0);
}
