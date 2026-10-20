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
uniform float application_clock=0.0;
uniform float application_alpha=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform bool Enable_UVPolar_base = true;
uniform float UVPolar_zoom = 1.0;
uniform float UVPolar_repeat = 1.0;
uniform vec2 Velocity_vector;
uniform sampler2D Noise_Texture : source_color, repeat_enable;
uniform bool Enable_UVPolar_Add;
uniform float UVPolar_zoom_add = 1.0;
uniform float UVPolar_repeat_add = 1.0;
uniform sampler2D Add_Texture_Mask : source_color, filter_linear, repeat_disable;
uniform bool Enable_UVPolar;
uniform float UVPolar_zoom2 = 1.0;
uniform float UVPolar_repeat2 = 1.0;
uniform vec2 Multiply_Offset = vec2(0.000000, 0.000000);
uniform sampler2D Multiply_Texture_Mask : source_color, filter_linear, repeat_disable;
uniform sampler2D Color_1D_gradient : source_color, filter_linear, repeat_disable;
uniform float Vanishing_value : hint_range(0.0, 1.0) = 1.0;



void fragment() {
// BooleanParameter:42
	bool n_out42p0 = Enable_UVPolar_base;


// FloatParameter:14
	float n_out14p0 = UVPolar_zoom;


// FloatParameter:13
	float n_out13p0 = UVPolar_repeat;


	vec2 n_out3p0;
// UVPolarCoord:3
	vec2 n_in3p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = UV - n_in3p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out3p0 = vec2(__radius * n_out14p0, __angle * n_out13p0);
	}


// Input:40
	vec2 n_out40p0 = UV;


	vec2 n_out41p0;
// Switch:41
	n_out41p0 = mix(n_out40p0, n_out3p0, float(n_out42p0));


// Input:7
	float n_out7p0 = application_clock;


// Vector2Parameter:8
	vec2 n_out8p0 = Velocity_vector;


// VectorOp:9
	vec2 n_out9p0 = vec2(n_out7p0) * n_out8p0;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out41p0;


	vec4 n_out5p0;
// Texture2D:5
	n_out5p0 = texture(Noise_Texture, n_out6p0);
	float n_out5p1 = n_out5p0.r;


// BooleanParameter:31
	bool n_out31p0 = Enable_UVPolar_Add;


// FloatParameter:26
	float n_out26p0 = UVPolar_zoom_add;


// FloatParameter:25
	float n_out25p0 = UVPolar_repeat_add;


	vec2 n_out27p0;
// UVPolarCoord:27
	vec2 n_in27p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = UV - n_in27p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out27p0 = vec2(__radius * n_out26p0, __angle * n_out25p0);
	}


// Input:28
	vec2 n_out28p0 = UV;


	vec2 n_out32p0;
// Switch:32
	n_out32p0 = mix(n_out28p0, n_out27p0, float(n_out31p0));


// UVFunc:29
	vec2 n_in29p1 = vec2(1.00000, 1.00000);
	vec2 n_in29p2 = vec2(0.00000, 0.00000);
	vec2 n_out29p0 = n_in29p2 * n_in29p1 + n_out32p0;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Add_Texture_Mask, n_out29p0);
	float n_out33p1 = n_out33p0.r;


// FloatOp:34
	float n_out34p0 = n_out5p1 + n_out33p1;


// Clamp:43
	float n_in43p1 = 0.00000;
	float n_in43p2 = 1.00000;
	float n_out43p0 = clamp(n_out34p0, n_in43p1, n_in43p2);


// BooleanParameter:23
	bool n_out23p0 = Enable_UVPolar;


// FloatParameter:20
	float n_out20p0 = UVPolar_zoom2;


// FloatParameter:19
	float n_out19p0 = UVPolar_repeat2;


	vec2 n_out21p0;
// UVPolarCoord:21
	vec2 n_in21p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = UV - n_in21p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out21p0 = vec2(__radius * n_out20p0, __angle * n_out19p0);
	}


// Input:24
	vec2 n_out24p0 = UV;


	vec2 n_out22p0;
// Switch:22
	n_out22p0 = mix(n_out24p0, n_out21p0, float(n_out23p0));


// Vector2Parameter:39
	vec2 n_out39p0 = Multiply_Offset;


// UVFunc:18
	vec2 n_in18p1 = vec2(1.00000, 1.00000);
	vec2 n_out18p0 = n_out39p0 * n_in18p1 + n_out22p0;


	vec4 n_out12p0;
// Texture2D:12
	n_out12p0 = texture(Multiply_Texture_Mask, n_out18p0);
	float n_out12p1 = n_out12p0.r;


// FloatOp:10
	float n_out10p0 = n_out43p0 * n_out12p1;


	vec4 n_out36p0;
// Texture2D:36
	n_out36p0 = texture(Color_1D_gradient, vec2(n_out10p0));
	float n_out36p4 = n_out36p0.a;


// FloatParameter:37
	float n_out37p0 = Vanishing_value;


// FloatOp:38
	float n_out38p0 = n_out36p4 * n_out37p0;


// Output:0
	ALBEDO = vec3(n_out36p0.xyz);
	ALPHA = n_out38p0;



ALPHA *= application_alpha;

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




