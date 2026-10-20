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

uniform float Wave_Speed = 1.0;
uniform sampler2D tex_vtx_16 : source_color;
uniform sampler2D tex_vtx_20 : source_color;
uniform float Wave_Intensity = 0.80000001192093;
uniform float Dissapear_Step = 0.10000000149012;
uniform vec2 Fire_Scale = vec2(3.000000, 2.000000);
uniform vec2 Fire_Speed = vec2(0.100000, 2.000000);
uniform sampler2D Fire_Texture : source_color, repeat_enable;
uniform sampler2D Gradient_Substract : source_color, filter_linear, repeat_enable;
uniform float power = 1.0;
uniform sampler2D Gradient_1D_Color : source_color, filter_linear, repeat_enable;



void vertex() {
// Input:2
	vec3 n_out2p0 = NORMAL;


// Input:6
	float n_out6p0 = orb_burst_seconds;


// FloatParameter:8
	float n_out8p0 = Wave_Speed;


// FloatOp:14
	float n_out14p0 = n_out6p0 * n_out8p0;


// VectorCompose:18
	float n_in18p0 = 0.00000;
	vec2 n_out18p0 = vec2(n_in18p0, n_out14p0);


// UVFunc:17
	vec2 n_in17p1 = vec2(1.00000, 1.00000);
	vec2 n_out17p0 = n_out18p0 * n_in17p1 + UV;


// Texture2D:16
	vec4 n_out16p0 = texture(tex_vtx_16, n_out17p0);
	float n_out16p1 = n_out16p0.r;


// Texture2D:20
	vec4 n_out20p0 = texture(tex_vtx_20, UV);
	float n_out20p1 = n_out20p0.r;


// FloatOp:19
	float n_out19p0 = n_out16p1 * n_out20p1;


// FloatParameter:22
	float n_out22p0 = Wave_Intensity;


// FloatOp:21
	float n_out21p0 = n_out19p0 * n_out22p0;


// VectorOp:5
	vec3 n_out5p0 = n_out2p0 * vec3(n_out21p0);


// Input:4
	vec3 n_out4p0 = VERTEX;


// VectorOp:3
	vec3 n_out3p0 = n_out5p0 + n_out4p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
// FloatParameter:47
	float n_out47p0 = Dissapear_Step;


// Vector2Parameter:38
	vec2 n_out38p0 = Fire_Scale;


// UVFunc:21
	vec2 n_in21p2 = vec2(0.00000, 0.00000);
	vec2 n_out21p0 = (UV - n_in21p2) * n_out38p0 + n_in21p2;


// Input:13
	float n_out13p0 = orb_burst_seconds;


// Vector2Parameter:39
	vec2 n_out39p0 = Fire_Speed;


// VectorOp:15
	vec2 n_out15p0 = vec2(n_out13p0) * n_out39p0;


// UVFunc:16
	vec2 n_in16p1 = vec2(1.00000, 1.00000);
	vec2 n_out16p0 = n_out15p0 * n_in16p1 + n_out21p0;


	vec4 n_out44p0;
// Texture2D:44
	n_out44p0 = texture(Fire_Texture, n_out16p0);
	float n_out44p1 = n_out44p0.r;


	vec4 n_out55p0;
// Texture2D:55
	n_out55p0 = texture(Gradient_Substract, UV);
	float n_out55p1 = n_out55p0.r;


// FloatOp:23
	float n_out23p0 = n_out44p1 - n_out55p1;


// FloatParameter:58
	float n_out58p0 = power;


// FloatOp:57
	float n_out57p0 = pow(max(n_out23p0,0.0),n_out58p0);


// SmoothStep:40
	float n_in40p1 = 1.00000;
	float n_out40p0 = smoothstep(n_out47p0, n_in40p1, n_out57p0);


// Clamp:41
	float n_in41p1 = 0.00000;
	float n_in41p2 = 1.00000;
	float n_out41p0 = clamp(n_out40p0, n_in41p1, n_in41p2);


	vec4 n_out60p0;
// Texture2D:60
	n_out60p0 = texture(Gradient_1D_Color, vec2(n_out41p0));


// Output:0
	ALBEDO = vec3(n_out60p0.xyz);
	ALPHA = n_out41p0;



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




