uniform int gpu_wizard_kind = 0;
uniform int gpu_wizard_piece = 0;
uniform int gpu_wizard_segments = 16;
uniform float gpu_wizard_motion = 0.;
uniform sampler2D gpu_stroke_points : filter_nearest, repeat_disable;

vec3 gpu_wizard_point(int station) {
	float along = float(station) / float(gpu_wizard_segments);
	if (gpu_wizard_kind == 0) {
		float angle = 6.28318530718 * float(gpu_wizard_piece) / 6.;
		float radial = mix(.29 - along * .16, .055 + along * .025, gpu_wizard_motion);
		float turn = angle + along * .52;
		return vec3(cos(turn) * radial, sin(along * 3.14159265359) * .065 + (along - .5) * .08, sin(turn) * radial);
	}
	if (gpu_wizard_kind == 1) {
		float angle = float(gpu_wizard_piece) * 6.28318530718 / 3.;
		float reach = (1. - along) * mix(.23, .12, gpu_wizard_motion);
		float phase = angle + along * .9;
		return vec3(cos(phase) * reach, sin(phase) * reach, (along - .5) * .11);
	}
	vec3 from = texelFetch(gpu_stroke_points, ivec2(station, 0), 0).xyz;
	vec3 to = texelFetch(gpu_stroke_points, ivec2(station, 1), 0).xyz;
	float stagger = clamp(gpu_wizard_motion * 1.6 - float(gpu_wizard_piece) * .045, 0., 1.);
	vec3 result = mix(from, to, stagger);
	result.y += sin(stagger * 3.14159265359) * (.11 + float(gpu_wizard_piece % 3) * .024);
	return result;
}

void gpu_directed_vertex(inout vec3 point, inout vec3 normal, inout vec3 tangent, inout vec3 binormal) {
	int station = int(point.x + .5);
	float side = point.y - .5;
	vec3 direction = normalize(gpu_wizard_point(min(station + 1, gpu_wizard_segments)) - gpu_wizard_point(max(station - 1, 0)));
	vec3 hint = gpu_wizard_kind == 1 ? vec3(0., 0., -1.) : vec3(0., 1., 0.);
	vec3 across = cross(direction, hint);
	across = length(across) > .000001 ? normalize(across) : vec3(1., 0., 0.);
	float width = gpu_wizard_kind == 0 ? mix(.038, .023, gpu_wizard_motion) : gpu_wizard_kind == 1 ? .045 * (1. - gpu_wizard_motion * .32) : .014;
	point = gpu_wizard_point(station) + across * width * side;
	normal = hint;
}
