uniform sampler2D gpu_body_points : filter_nearest, repeat_disable;
uniform int gpu_body_count = 0;
uniform int gpu_form_profile = 0;
uniform bool gpu_form_readable = false;
uniform vec3 gpu_body_up = vec3(0., 1., 0.);
uniform vec3 gpu_body_side = vec3(1., 0., 0.);
uniform vec2 gpu_body_radii = vec2(.1);
uniform float gpu_form_phase = 0.;
uniform float gpu_form_heading_bias=0.;
uniform float gpu_form_width = .02;
uniform float gpu_form_camber = .01;

void gpu_body_support(float along, float across, out vec3 position, out vec3 normal) {
	vec4 best = vec4(1e30);
	ivec4 nearest = ivec4(0);
	for (int index = 0; index < gpu_body_count; index++) {
		vec3 point = texelFetch(gpu_body_points, ivec2(index, 0), 0).xyz;
		vec2 delta = vec2(dot(point, gpu_body_up) - along, dot(point, gpu_body_side) - across);
		float distance = dot(delta, delta);
		if (distance < best.w) {
			int slot = 3;
			for (int candidate = 0; candidate < 3; candidate++) {
				if (distance < best[candidate]) { slot = candidate; break; }
			}
			for (int candidate = 3; candidate > slot; candidate--) {
				best[candidate] = best[candidate - 1];
				nearest[candidate] = nearest[candidate - 1];
			}
			best[slot] = distance;
			nearest[slot] = index;
		}
	}
	position = vec3(0.);
	normal = vec3(0.);
	float total = 0.;
	for (int candidate = 0; candidate < 4; candidate++) {
		float weight = 1. / (best[candidate] + .00015);
		position += texelFetch(gpu_body_points, ivec2(nearest[candidate], 0), 0).xyz * weight;
		normal += texelFetch(gpu_body_points, ivec2(nearest[candidate], 1), 0).xyz * weight;
		total += weight;
	}
	position /= total;
	normal = normalize(normal);
	position += gpu_body_up * (along - dot(position, gpu_body_up)) + gpu_body_side * (across - dot(position, gpu_body_side));
}

void gpu_form_station(int station, int piece_index, out vec3 position, out vec3 normal, out float width) {
	float along_path = float(station) / 32.;
	float index = float(piece_index);
	float parity = piece_index % 2 == 0 ? -1. : 1.;
	float phase = gpu_form_phase * (gpu_form_readable && gpu_form_profile == 4 ? parity : 1.) + gpu_form_heading_bias + index * 2.17;
	float height = gpu_body_radii.x;
	float horizontal = gpu_body_radii.y;
	float along = 0.;
	float across = 0.;
	float clearance = 0.;
	float wave = sin(along_path * 3.14159265359);
	if (gpu_form_readable && gpu_form_profile == 1) {
		along = height * (-.65 + 1.35 * along_path) + .012 * sin(phase + along_path * 3.14159265359);
		across = parity * horizontal * (.85 - .28 * wave + .08 * sin(phase));
		clearance = .055 + .045 * wave + .015 * sin(phase);
	} else if (gpu_form_readable) {
		along = height * (-.75 + 1.25 * along_path + .12 * sin(along_path * 6.28318530718 + phase));
		across = parity * horizontal * (.72 + .5 * wave + .1 * sin(phase));
		clearance = .055 + .04 * index + .035 * sin(along_path * 3.14159265359 + phase);
	} else if (gpu_form_profile == 0) {
		along = height * (-.35 + 1.1 * along_path) + .03 * sin(phase + along_path * 3.14159265359);
		across = parity * horizontal * (.95 - .65 * along_path + .1 * sin(phase + along_path * 3.14159265359));
		clearance = .045 + .10 * wave + .018 * sin(phase);
	} else if (gpu_form_profile == 1) {
		float pair = floor(index / 2.);
		along = height * (-.65 + .75 * along_path + .22 * pair);
		across = parity * horizontal * (.95 - .42 * along_path + .09 * sin(phase + along_path * 6.28318530718));
		clearance = .035 + .03 * pair + .045 * sin(along_path * 3.14159265359 - phase * .5);
	} else if (gpu_form_profile == 2) {
		along = height * (.85 - 1.7 * along_path + .1 * sin(phase));
		across = horizontal * (index - 1.) * .73 + .035 * sin(along_path * 6.28318530718 + phase);
		clearance = .055 + .045 * index + .06 * sin(along_path * 3.14159265359 + phase);
	} else if (gpu_form_profile == 3) {
		along = height * ((index - 1.) * .5 + (along_path - .5) * .65 + .10 * sin(phase * 1.3));
		across = horizontal * (.7 * sin(along_path * 3.14159265359 * 1.35 + phase * .7) + parity * .22);
		clearance = .065 + .04 * index + .07 * wave * (.5 + .5 * sin(phase));
	} else {
		along = height * ((index - 1.) * .42 + .18 * sin(along_path * 6.28318530718 + phase));
		across = horizontal * ((along_path - .5) * 1.6 + .12 * sin(phase * parity));
		clearance = .04 + .045 * index + .035 * sin(along_path * 3.14159265359 + phase);
	}
	gpu_body_support(along, across, position, normal);
	position += normal * clearance;
	width = gpu_form_width * pow(max(0., wave), .85);
}

void gpu_directed_vertex(inout vec3 point, inout vec3 normal, inout vec3 tangent, inout vec3 binormal) {
	int station = int(point.x + .5);
	int piece_index = int(point.z + .5);
	float edge = point.y;
	vec3 position;
	vec3 before;
	vec3 after;
	vec3 source_normal;
	vec3 ignored_normal;
	float width;
	float ignored_width;
	gpu_form_station(station, piece_index, position, source_normal, width);
	gpu_form_station(max(0, station - 1), piece_index, before, ignored_normal, ignored_width);
	gpu_form_station(min(32, station + 1), piece_index, after, ignored_normal, ignored_width);
	vec3 direction = normalize(after - before);
	vec3 across = normalize(cross(source_normal, direction));
	point = position + across * edge * width + source_normal * (1. - edge * edge) * gpu_form_camber * sin(float(station) / 32. * 3.14159265359);
	normal = normalize(cross(across, direction));
}
