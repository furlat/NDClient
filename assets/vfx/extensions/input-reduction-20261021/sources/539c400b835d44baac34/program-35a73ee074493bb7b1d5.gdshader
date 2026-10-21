shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_receiving_clock=0.0;

uniform float receiving_clock=0.0;
uniform float receiving_envelope=0.0;
uniform float receiving_opacity=1.0;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform bool Enable_Distortion;
uniform vec2 distortion_scale = vec2(1.000000, 1.000000);
uniform vec2 distortion_speed = vec2(1.000000, 1.000000);
uniform sampler2D DistortionTexture : hint_normal, filter_linear;
uniform float DistortionStregnht = 0.01999999955297;
uniform vec2 scale = vec2(1.000000, 1.000000);
uniform vec2 speed = vec2(1.000000, 1.000000);
uniform sampler2D BaseTexture : source_color, repeat_enable;
uniform sampler2D Multiply_Mask : source_color, repeat_disable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform bool Use_Proximity_Fade = false;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_109 : hint_depth_texture;



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

void vertex() {gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);}
void fragment() {
// Input:104
	vec4 n_out104p0 = COLOR;


// BooleanParameter:113
	bool n_out113p0 = Enable_Distortion;


// Input:114
	vec2 n_out114p0 = UV;


// Vector2Parameter:10
	vec2 n_out10p0 = distortion_scale;


// UVFunc:17
	vec2 n_in17p2 = vec2(0.00000, 0.00000);
	vec2 n_out17p0 = (UV - n_in17p2) * n_out10p0 + n_in17p2;


// Input:7
	float n_out7p0 = (vfx_package_seconds()+vfx_package_offset_receiving_clock);


// Vector2Parameter:8
	vec2 n_out8p0 = distortion_speed;


// VectorOp:9
	vec2 n_out9p0 = vec2(n_out7p0) * n_out8p0;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out17p0;


	vec4 n_out12p0;
// Texture2D:12
	n_out12p0 = texture(DistortionTexture, n_out6p0);
	float n_out12p1 = n_out12p0.r;
	float n_out12p2 = n_out12p0.g;


// VectorCompose:3
	vec2 n_out3p0 = vec2(n_out12p1, n_out12p2);


// FloatParameter:19
	float n_out19p0 = DistortionStregnht;


// VectorOp:15
	vec2 n_out15p0 = n_out3p0 * vec2(n_out19p0);


// VectorOp:13
	vec2 n_out13p0 = n_out114p0 - n_out15p0;


// Input:112
	vec2 n_out112p0 = UV;


	vec2 n_out111p0;
// Switch:111
	n_out111p0 = mix(n_out112p0, n_out13p0, float(n_out113p0));


// Vector2Parameter:98
	vec2 n_out98p0 = scale;


// UVFunc:97
	vec2 n_in97p2 = vec2(0.00000, 0.00000);
	vec2 n_out97p0 = (n_out111p0 - n_in97p2) * n_out98p0 + n_in97p2;


// Input:94
	float n_out94p0 = (vfx_package_seconds()+vfx_package_offset_receiving_clock);


// Vector2Parameter:95
	vec2 n_out95p0 = speed;


// VectorOp:96
	vec2 n_out96p0 = vec2(n_out94p0) * n_out95p0;


// UVFunc:93
	vec2 n_in93p1 = vec2(1.00000, 1.00000);
	vec2 n_out93p0 = n_out96p0 * n_in93p1 + n_out97p0;


	vec4 n_out92p0;
// Texture2D:92
	n_out92p0 = texture(BaseTexture, n_out93p0);
	float n_out92p1 = n_out92p0.r;


	vec4 n_out102p0;
// Texture2D:102
	n_out102p0 = texture(Multiply_Mask, UV);
	float n_out102p1 = n_out102p0.r;


// FloatOp:103
	float n_out103p0 = n_out92p1 * n_out102p1;


	vec4 n_out100p0;
// Texture2D:100
	n_out100p0 = texture(Color1DGradient, vec2(n_out103p0));


// VectorOp:105
	vec4 n_out105p0 = n_out104p0 * n_out100p0;
	float n_out105p4 = n_out105p0.a;


// BooleanParameter:108
	bool n_out108p0 = Use_Proximity_Fade;


// FloatParameter:110
	float n_out110p0 = Proximity_Fade;


	float n_out109p0;
// ProximityFade:109
	{
		float __depth_tex = texture(depth_tex_frg_109, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out109p0 = ((isnan(VERTEX.z-__depth_world_pos.z) || isinf(VERTEX.z-__depth_world_pos.z)) ? 1.0 : smoothstep(0.0, max(n_out110p0, 0.0001), VERTEX.z-__depth_world_pos.z));
	}


// FloatOp:106
	float n_out106p0 = n_out105p4 * n_out109p0;


	float n_out107p0;
// Switch:107
	n_out107p0 = mix(n_out105p4, n_out106p0, float(n_out108p0));


// Output:0
	ALBEDO = vec3(n_out105p0.xyz);
	ALPHA = n_out107p0;



ALPHA=pow(clamp(ALPHA,0.0,1.0),0.55);
ALPHA*=receiving_envelope*receiving_opacity*0.9;
}

