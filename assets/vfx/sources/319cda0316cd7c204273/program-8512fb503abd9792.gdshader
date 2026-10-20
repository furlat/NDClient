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

render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform sampler2D tex_frg_2 : source_color;
uniform sampler2D tex_frg_7 : source_color;
uniform sampler2D tex_frg_11 : source_color;



void vertex() {}
void fragment() {
// Input:4
	vec4 n_out4p0 = smite_source_colour;
	float n_out4p1 = n_out4p0.r;


// Vector2Constant:6
	vec2 n_out6p0 = vec2(0.000000, 2.000000);


// VectorOp:5
	vec2 n_out5p0 = vec2(n_out4p1) * n_out6p0;


// UVFunc:3
	vec2 n_in3p1 = vec2(1.00000, 1.00000);
	vec2 n_out3p0 = n_out5p0 * n_in3p1 + UV;


// Texture2D:2
	vec4 n_out2p0 = texture(tex_frg_2, n_out3p0);
	float n_out2p1 = n_out2p0.r;


// Texture2D:7
	vec4 n_out7p0 = texture(tex_frg_7, vec2(n_out2p0.xy));


// Input:12
	float n_out12p0 = smite_clock;


// FloatOp:15
	float n_in15p1 = 15.00000;
	float n_out15p0 = n_out12p0 * n_in15p1;


// FloatFunc:13
	float n_out13p0 = sin(n_out15p0);


	float n_out14p0;
// Remap:14
	float n_in14p1 = -1.00000;
	float n_in14p2 = 1.00000;
	float n_in14p3 = 0.00000;
	float n_in14p4 = 0.70000;
	{
		float __input_range = n_in14p2 - n_in14p1;
		float __output_range = n_in14p4 - n_in14p3;
		n_out14p0 = n_in14p3 + __output_range * ((n_out13p0 - n_in14p1) / __input_range);
	}


// SmoothStep:8
	float n_in8p1 = 0.70000;
	float n_out8p0 = smoothstep(n_out14p0, n_in8p1, n_out2p1);


// FloatOp:9
	float n_in9p1 = 0.50000;
	float n_out9p0 = pow(n_out8p0, n_in9p1);


// Texture2D:11
	vec4 n_out11p0 = texture(tex_frg_11, UV);
	float n_out11p1 = n_out11p0.r;


// FloatOp:10
	float n_out10p0 = n_out9p0 * n_out11p1;


// Output:0
	ALBEDO = vec3(n_out7p0.xyz);
	ALPHA = n_out10p0;



ALPHA=(.25+.75*clamp(ALPHA,0.0,1.0))*smoothstep(.48,.75,UV2.y)*smite_envelope*.46;

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



