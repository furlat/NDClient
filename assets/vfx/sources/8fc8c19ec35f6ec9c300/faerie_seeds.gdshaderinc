uniform sampler2D gpu_faerie_data : filter_nearest, repeat_disable;
uniform float gpu_faerie_time = 0.;
varying float gpu_instance_gate;
varying float gpu_faerie_seed;

vec3 gpu_faerie_point(int station, vec4 base, vec4 direction, float age) {
	float along = float(station) / 8.;
	return vec3(base.x, .08 + max(0., age) * .35, base.y) + vec3(direction.x * sin(along * 3.14159265359) * .035, along * .13, direction.y * sin(along * 3.14159265359) * .035);
}

void gpu_instance_vertex(inout vec3 point, inout vec3 normal, inout vec3 tangent, inout vec3 binormal, int mote_index, out float strength) {
	vec4 base = texelFetch(gpu_faerie_data, ivec2(0, mote_index), 0);
	vec4 direction = texelFetch(gpu_faerie_data, ivec2(1, mote_index), 0);
	int station = int(point.x + .5);
	float edge = point.y;
	float fin = point.z;
	float age = gpu_faerie_time - base.z;
	float along = float(station) / 8.;
	vec3 heading = normalize(gpu_faerie_point(min(station + 1, 8), base, direction, age) - gpu_faerie_point(max(station - 1, 0), base, direction, age));
	vec3 hint = abs(dot(heading, vec3(0., 1., 0.))) > .99 ? vec3(1., 0., 0.) : vec3(0., 1., 0.);
	vec3 side = normalize(cross(heading, hint));
	float angle = fin * 6.28318530718 / 3.;
	side = side * cos(angle) + cross(heading, side) * sin(angle) + heading * dot(heading, side) * (1. - cos(angle));
	normal = normalize(cross(side, heading));
	point = gpu_faerie_point(station, base, direction, age) + side * .014 * pow(max(0., sin(along * 3.14159265359)), .7) * edge;
	float envelope = smoothstep(0., .16, age) * (1. - smoothstep(.42, .78, age));
	strength = envelope > .001 ? envelope : 0.;
}
