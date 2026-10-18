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

uniform vec3 gpu_vane_centre;
uniform float gpu_vane_rate=1.;
uniform bool gpu_vane_sheet=false;
uniform float gpu_vane_period=1.8;
uniform float gpu_vane_alpha=.7;
uniform bool gpu_vane_removal=false;
uniform float gpu_vane_duration=1.;

void gpu_body_support(float along, float across, out vec3 position, out vec3 normal) {
	vec4 best = vec4(1e30);
	ivec4 nearest = ivec4(0);
	for (int index = 0; index < gpu_body_count; index++) {
		vec3 point = texelFetch(gpu_body_points, ivec2(index, 0), 0).xyz;
		vec2 delta = vec2(dot(point, gpu_body_up) - along, dot(point-gpu_vane_centre, gpu_body_side) - across);
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

void gpu_vane_station(int station,int piece_index,out vec3 point,out vec3 normal,out float width,out float camber){
	float u=float(station)/32.;float number=float(piece_index);
	float parity=piece_index%2==0 ? -1. : 1.; float tier=floor(number/2.);
	float wave=sin(gpu_form_phase*gpu_vane_rate-u*6.28318530718+number);
	float across;float elevation;float clearance;
	if(gpu_form_profile==0){
		across=parity*gpu_body_radii.y*(.78+.18*sin(u*3.14159265359));
		elevation=gpu_body_radii.x*(.49+u*.32+tier*.035);
		clearance=.045+.035*sin(u*3.14159265359)+.009*wave;
		width=gpu_form_width*pow(max(0.,sin(u*3.14159265359)),.8);
	}else{
		across=parity*(gpu_body_radii.y*.68+u*.16);
		elevation=gpu_body_radii.x*(.74-tier*.085)+.035*sin(u*3.14159265359+gpu_form_phase*.7+number);
		clearance=.04+.065*sin(u*3.14159265359)+.01*wave;
		width=gpu_form_width*pow(max(0.,sin(u*3.14159265359)),.65);
	}
	gpu_body_support(elevation,across,point,normal);
	point+=normal*clearance;
	point+=gpu_body_side*parity*(gpu_form_profile==0 ? (.02*sin(u*3.14159265359)+tier*.02) : u*.08);
	if(gpu_vane_removal)point+=normal*.045*smoothstep(0.,gpu_vane_duration,gpu_form_phase);
	camber=.028*sin(u*3.14159265359);
}
void gpu_vane_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,out float source_alpha){
	int station=int(point.x+.5);int piece_index=int(point.z+.5);float edge=point.y;
	vec3 centre;vec3 before;vec3 after;vec3 source_normal;vec3 ignored;
	float width;float camber;float ignored_width;float ignored_camber;
	gpu_vane_station(station,piece_index,centre,source_normal,width,camber);
	gpu_vane_station(max(0,station-1),piece_index,before,ignored,ignored_width,ignored_camber);
	gpu_vane_station(min(32,station+1),piece_index,after,ignored,ignored_width,ignored_camber);
	vec3 direction=normalize(after-before);
	vec3 across=gpu_form_profile==0 ? gpu_body_side : vec3(0.,1.,0.);
	point=centre+across*edge*width+source_normal*(1.-edge*edge)*camber;
	vec3 derivative=across*width-source_normal*2.*edge*camber;
	normal=normalize(cross(derivative,direction));
	source_alpha=gpu_vane_sheet ? mod(gpu_form_phase/gpu_vane_period+float(piece_index)*.19,1.) : gpu_vane_alpha;
}
// Geometry-only readback uses this entry; the real vertex also writes COLOR.a.
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal){
	float source_alpha;gpu_vane_vertex(point,normal,tangent,binormal,source_alpha);
}
