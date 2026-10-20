shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

// Shared numerical contract: encoded sRGB -> D65 CIELAB, CIE76 distance.
// Constants and branch boundaries preserve the selected CodexFX profile.
// Alpha, RGB snapping, ramps and energy keys belong to the caller.
float cie_linear_channel(float channel) {
	return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4);
}
float cie_encoded_channel(float channel) {
	return channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(max(channel, 0.0), 1.0 / 2.4) - 0.055;
}
float cie_lab_curve(float value) {
	return value > 0.00885645167 ? pow(value, 1.0 / 3.0) : 7.78703703704 * value + 16.0 / 116.0;
}
vec3 cie_lab(vec3 encoded_rgb) {
	vec3 linear_rgb = vec3(cie_linear_channel(encoded_rgb.r), cie_linear_channel(encoded_rgb.g), cie_linear_channel(encoded_rgb.b));
	float x = linear_rgb.r * 0.4124564 + linear_rgb.g * 0.3575761 + linear_rgb.b * 0.1804375;
	float y = linear_rgb.r * 0.2126729 + linear_rgb.g * 0.7151522 + linear_rgb.b * 0.0721750;
	float z = linear_rgb.r * 0.0193339 + linear_rgb.g * 0.1191920 + linear_rgb.b * 0.9503041;
	float fx = cie_lab_curve(x / 0.95047);
	float fy = cie_lab_curve(y);
	float fz = cie_lab_curve(z / 1.08883);
	return vec3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
}
vec3 cie_nearest(vec3 encoded_rgb, sampler2D palette_texture, int count, float energy_floor, float luma_floor) {
	vec3 subject_lab = cie_lab(encoded_rgb);
	float best_distance = 999999.0;
	vec3 best_rgb = encoded_rgb;
	for (int index = 0; index < 64; index++) {
		if (index >= count) { break; }
		vec3 candidate = texture(palette_texture, vec2((float(index) + 0.5) / float(count), 0.5)).rgb;
		if (max(max(candidate.r, candidate.g), candidate.b) < energy_floor || dot(candidate, vec3(0.2126, 0.7152, 0.0722)) < luma_floor) { continue; }
		float candidate_distance = distance(subject_lab, cie_lab(candidate));
		// Strict less-than deliberately keeps the first palette entry on ties.
		if (candidate_distance < best_distance) {
			best_distance = candidate_distance;
			best_rgb = candidate;
		}
	}
	return best_rgb;
}


uniform sampler2D native_palette_texture:filter_nearest,repeat_disable;
uniform int native_palette_count=1;
uniform bool native_palette_quantize=true;
uniform float native_emission_gain=0.0;
uniform float native_palette_exposure=1.0;
uniform float orb_burst_seconds=0.0;
uniform float orb_burst_envelope=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D Gradient_Disolver : source_color, filter_linear, repeat_enable;
uniform float Edge_Cut_Line : hint_range(0.0, 1.0) = 0.40000000596046;
uniform vec2 Trail_Scale = vec2(3.000000, 2.000000);
uniform vec2 Trail_Speed = vec2(0.100000, 2.000000);
uniform sampler2D Trail_Texture : source_color, repeat_enable;
uniform sampler2D Overlapping_Gradient : source_color, repeat_disable;



uniform sampler2D gpu_path_points : filter_nearest, repeat_disable;
instance uniform int gpu_path_count = 2;
instance uniform int gpu_path_row = 0;
void gpu_path_station(int index,out vec3 point,out float width) {
	vec4 data=texelFetch(gpu_path_points,ivec2(index,gpu_path_row),0);
	point=data.xyz; width=data.a;
}
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	int station=int(point.x+.5); float edge=point.y; float fin=point.z;
	vec3 centre; vec3 before; vec3 after; float width; float ignored;
	gpu_path_station(station,centre,width);
	gpu_path_station(max(0,station-1),before,ignored);
	gpu_path_station(min(gpu_path_count-1,station+1),after,ignored);
	vec3 direction=length(after-before)<.000001 ? vec3(0.,0.,-1.) : normalize(after-before);
	vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.99 ? vec3(1.,0.,0.) : vec3(0.,1.,0.);
	vec3 base=normalize(cross(direction,reference));
	float angle=fin*6.28318530718/3.;
	vec3 side=base*cos(angle)+cross(direction,base)*sin(angle)+direction*dot(direction,base)*(1.-cos(angle));
	point=centre+side*width*edge;
	normal=normalize(cross(side,direction));
}

void vertex() {gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
	vec4 n_out66p0;
// Texture2D:66
	n_out66p0 = texture(Gradient_Disolver, UV);
	float n_out66p1 = n_out66p0.r;


// FloatParameter:68
	float n_out68p0 = Edge_Cut_Line;


// Vector2Parameter:54
	vec2 n_out54p0 = Trail_Scale;


// UVFunc:53
	vec2 n_in53p2 = vec2(0.00000, 0.00000);
	vec2 n_out53p0 = (UV - n_in53p2) * n_out54p0 + n_in53p2;


// Input:50
	float n_out50p0 = orb_burst_seconds;


// Vector2Parameter:55
	vec2 n_out55p0 = Trail_Speed;


// VectorOp:51
	vec2 n_out51p0 = vec2(n_out50p0) * n_out55p0;


// UVFunc:52
	vec2 n_in52p1 = vec2(1.00000, 1.00000);
	vec2 n_out52p0 = n_out51p0 * n_in52p1 + n_out53p0;


	vec4 n_out57p0;
// Texture2D:57
	n_out57p0 = texture(Trail_Texture, n_out52p0);
	float n_out57p1 = n_out57p0.r;


// SmoothStep:67
	float n_out67p0 = smoothstep(n_out66p1, n_out68p0, n_out57p1);


	vec4 n_out63p0;
// Texture2D:63
	n_out63p0 = texture(Overlapping_Gradient, vec2(n_out67p0));


// Output:0
	ALBEDO = vec3(n_out63p0.xyz);
	ALPHA = n_out67p0;



ALPHA*=orb_burst_envelope;

	float native_raw_energy = max(max(ALBEDO.r + EMISSION.r, ALBEDO.g + EMISSION.g), ALBEDO.b + EMISSION.b);
	native_raw_energy *= native_palette_exposure;
	float native_energy = native_raw_energy / (1.0 + native_raw_energy);
	float native_position = native_energy * float(native_palette_count - 1);
	int native_first = int(floor(native_position));
	int native_second = min(native_first + 1, native_palette_count - 1);
	vec3 native_a = texture(native_palette_texture, vec2((float(native_first) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_b = texture(native_palette_texture, vec2((float(native_second) + 0.5) / float(native_palette_count), 0.5)).rgb;
	vec3 native_choice = mix(native_a, native_b, fract(native_position));
	if (native_palette_quantize) native_choice = cie_nearest(native_choice, native_palette_texture, native_palette_count, 0.0, 0.0);
	ALBEDO = vec3(cie_linear_channel(native_choice.r), cie_linear_channel(native_choice.g), cie_linear_channel(native_choice.b));
	EMISSION = ALBEDO * min(native_raw_energy, 2.0) * native_emission_gain;
	
ALPHA *= factory_occurrence_alpha;
}




