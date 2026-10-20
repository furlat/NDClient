shader_type spatial;
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
uniform float smite_clock=0.0;
uniform float smite_envelope=0.0;
uniform vec4 smite_source_colour=vec4(1.0);

render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform vec4 ColorParameter : source_color = vec4(5.000000, 0.800000, 0.000000, 1.000000);
uniform vec2 Speed = vec2(0.000000, 1.200000);
uniform sampler2D Distortion_TEx;
uniform float Distortion_ammount = 2.0;
uniform sampler2D tex_frg_27;
uniform sampler2D tex_frg_38;
uniform sampler2D Main_TEX;



void vertex() {}
void fragment() {
// ColorParameter:57
	vec4 n_out57p0 = ColorParameter;


// Input:2
	vec2 n_out2p0 = UV;


// Input:13
	float n_out13p0 = smite_clock;


// Vector2Parameter:61
	vec2 n_out61p0 = Speed;


// VectorOp:14
	vec2 n_out14p0 = vec2(n_out13p0) * n_out61p0;


// UVFunc:10
	vec2 n_in10p1 = vec2(1.00000, 1.00000);
	vec2 n_out10p0 = n_out14p0 * n_in10p1 + UV;


// VectorOp:25
	vec2 n_in25p1 = vec2(1.00000, 1.00000);
	vec2 n_out25p0 = n_out10p0 / n_in25p1;


	vec4 n_out63p0;
// Texture2D:63
	n_out63p0 = texture(Distortion_TEx, n_out25p0);


// VectorDecompose:24
	float n_out24p0 = n_out63p0.x;
	float n_out24p1 = n_out63p0.y;
	float n_out24p2 = n_out63p0.z;
	float n_out24p3 = n_out63p0.w;


// FloatParameter:64
	float n_out64p0 = Distortion_ammount;


// FloatOp:3
	float n_out3p0 = n_out24p0 / n_out64p0;


// Texture2D:27
	vec4 n_out27p0 = texture(tex_frg_27, UV);


// VectorDecompose:28
	float n_out28p0 = n_out27p0.x;
	float n_out28p1 = n_out27p0.y;
	float n_out28p2 = n_out27p0.z;
	float n_out28p3 = n_out27p0.w;


// Texture2D:38
	vec4 n_out38p0 = texture(tex_frg_38, UV);


// VectorDecompose:39
	float n_out39p0 = n_out38p0.x;
	float n_out39p1 = n_out38p0.y;
	float n_out39p2 = n_out38p0.z;
	float n_out39p3 = n_out38p0.w;


// FloatOp:56
	float n_in56p1 = 0.30000;
	float n_out56p0 = pow(n_out39p0, n_in56p1);


// FloatOp:40
	float n_out40p0 = n_out28p0 * n_out56p0;


// FloatOp:26
	float n_out26p0 = n_out3p0 * n_out40p0;


// VectorOp:7
	vec2 n_out7p0 = n_out2p0 + vec2(n_out26p0);


// UVFunc:4
	vec2 n_in4p1 = vec2(1.00000, 1.00000);
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = n_in4p2 * n_in4p1 + n_out7p0;


// VectorOp:35
	vec2 n_in35p1 = vec2(1.00000, 1.00000);
	vec2 n_out35p0 = n_out4p0 / n_in35p1;


	vec4 n_out60p0;
// Texture2D:60
	n_out60p0 = texture(Main_TEX, n_out35p0);


// VectorDecompose:19
	float n_out19p0 = n_out60p0.x;
	float n_out19p1 = n_out60p0.y;
	float n_out19p2 = n_out60p0.z;
	float n_out19p3 = n_out60p0.w;


// FloatOp:45
	float n_in45p1 = 1.00000;
	float n_out45p0 = pow(n_out19p0, n_in45p1);


// VectorOp:46
	vec4 n_out46p0 = n_out57p0 * vec4(n_out45p0);


// Output:0
	ALBEDO = vec3(n_out46p0.xyz);
	ALPHA = n_out19p0;



ALPHA=clamp(ALPHA,0.0,1.0)*smite_envelope*.32;

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
	}



