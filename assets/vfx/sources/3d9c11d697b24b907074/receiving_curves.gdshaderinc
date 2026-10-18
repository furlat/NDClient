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
	if (gpu_form_profile==2) position += gpu_body_up * (along - dot(position, gpu_body_up)) + gpu_body_side * (across - dot(position, gpu_body_side));
}

void gpu_form_station(int station,int piece_index,out vec3 position,out vec3 normal,out float width) {
	float u=float(station)/32.; float number=float(piece_index);
	float parity=piece_index%2==0 ? -1. : 1.;
	float phase=gpu_form_phase+number*2.1;
	float height=gpu_body_radii.x; float horizontal=gpu_body_radii.y;
	float along; float across; float clearance;
	if(gpu_form_profile==0){
		along=height*(.12+.48*sin(u*3.14159265359*.78));
		across=parity*horizontal*(.95-.78*u);
		clearance=.055+.075*sin(u*3.14159265359)+.012*sin(phase);
	}else if(gpu_form_profile==1){
		along=height*(-.72+u*1.35);
		across=parity*horizontal*(.55+.32*sin(u*6.28318530718-phase));
		clearance=.055+.075*(.5+.5*cos(u*6.28318530718-phase));
	}else{
		float measured_height=min(height*1.25,.13);float measured_width=min(horizontal*1.6,.17);
		along=measured_height*((u-.5)*1.35+parity*.28)+.015*sin(phase+u*6.28318530718);
		across=measured_width*((.5-u)*1.6+.2*sin(u*6.28318530718+phase)+parity*.18);
		clearance=.045+.035*number+.025*sin(u*3.14159265359+phase);
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
	vec3 across = normalize(cross(source_normal, direction));
	point = position + across * edge * width + source_normal * (1. - edge * edge) * gpu_form_camber * sin(float(station) / 32. * 3.14159265359);
	normal = normalize(cross(across, direction));
}
