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
	
}

void gpu_form_station(int station,int piece_index,out vec3 position,out vec3 normal,out float width){
	float u=float(station)/32.;float number=float(piece_index);float sign_value=piece_index%2==0 ? -1. : 1.;
	float phase=gpu_form_phase+number*1.9;
	float along;float across;float clearance;
	if(gpu_form_profile==0){
		along=(u-.5)*min(gpu_body_radii.x*1.1,.29)+.06*sin(phase*.6);
		across=sign_value*gpu_body_radii.y*(.55+.16*sin(u*3.14159265359));
		clearance=.045+.04*sin(u*3.14159265359)+.015*sin(phase);
	}else{
		along=(u-.5)*min(gpu_body_radii.x*1.35,.44);
		across=sign_value*gpu_body_radii.y*.55+.025*sin(u*6.28318530718+phase);
		clearance=.045+.035*sin(u*6.28318530718*1.5-phase);
	}
	gpu_body_support(along,across,position,normal);
	position+=normal*clearance;
	width=gpu_form_width*pow(max(0.,sin(u*3.14159265359)),.8);
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
	vec3 across = gpu_body_side;
	point = position + across * edge * width + source_normal * (1. - edge * edge) * gpu_form_camber * sin(float(station) / 32. * 3.14159265359);
	normal = normalize(cross(across, direction));
}
