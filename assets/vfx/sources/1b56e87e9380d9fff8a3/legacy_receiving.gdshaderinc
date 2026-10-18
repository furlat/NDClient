uniform bool gpu_legacy_tube = false;
uniform bool gpu_legacy_animal = false;
uniform int gpu_legacy_piece = 0;
uniform float gpu_legacy_seconds = 0.;

vec3 gpu_legacy_point(int station) {
	float index = float(gpu_legacy_piece);
	float seconds = gpu_legacy_seconds;
	float along = float(station) / 64.;
	float phase = seconds * 6.28318530718 / 4. + index * 2.13;
	float settled = smoothstep(.7, 1.5, seconds);
	float angle = phase + along * 6.28318530718 * mix(.72, gpu_legacy_piece == 0 ? .24 : .14, settled);
	float radius = mix(.68, .55, settled) + .06 * sin(along * 6.28318530718 * 2. + phase);
	float height = mix(.20 + 2.2 * along, (gpu_legacy_animal ? 2.35 : 1.1) + .35 * along + index * .12, settled) + .06 * sin(angle * 2. + index);
	return vec3(cos(angle) * radius, height, sin(angle) * radius);
}

vec3 gpu_legacy_position(vec3 point) {
	float index = float(gpu_legacy_piece);
	float seconds = gpu_legacy_seconds;
	if (!gpu_legacy_tube) {
		float along = point.x / 32.;
		float angle = index * 2.15 + seconds * (1.15 + .12 * index) + along * (1.8 + index * .15);
		float radius = .79 + .15 * sin(along * 3.14159265359 + seconds * 1.3 + index);
		float height = .36 + index * .30 + along * .35 + .12 * sin(seconds * 1.7 + along * 3. + index);
		float width = (.16 + index * .025) * pow(max(0., sin(along * 3.14159265359)), .6);
		point = vec3(cos(angle) * radius, height + point.y * width, sin(angle) * radius);
		return point;
	}
	int station = int(point.x + .5);
	int corner = int(point.y + .5);
	float face = point.z;
	vec3 heading = normalize(gpu_legacy_point(station + 1) - gpu_legacy_point(station));
	vec3 side = cross(heading, vec3(0., 1., 0.));
	if (length(side) < .01) side = cross(heading, vec3(1., 0., 0.));
	side = normalize(side);
	vec3 other = normalize(cross(heading, side));
	float angle = (face + float(corner >= 2)) * 6.28318530718 / 6.;
	float settled = smoothstep(.7, 1.5, seconds);
	float radius = gpu_legacy_animal ? mix(.045, .035, settled) : mix(.065, .043, settled);
	return gpu_legacy_point(station + int(corner == 1 || corner == 2)) + radius * (side * cos(angle) + other * sin(angle));
}

void gpu_directed_vertex(inout vec3 point, inout vec3 normal, inout vec3 tangent, inout vec3 binormal) {
	point = gpu_legacy_position(point);
	}

void gpu_legacy_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,vec3 second_descriptor,vec3 third_descriptor) {
	point = gpu_legacy_position(point);
	vec3 second = gpu_legacy_position(second_descriptor);
	vec3 third = gpu_legacy_position(third_descriptor);
	// SurfaceTool.generate_normals() uses Godot's clockwise triangle normal.
	normal = normalize(cross(third - point, second - point));
}
