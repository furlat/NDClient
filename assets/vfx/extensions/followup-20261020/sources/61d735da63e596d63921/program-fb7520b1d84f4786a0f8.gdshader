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
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform bool UseProximityFade = true;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed;
uniform sampler2D Texture : source_color, repeat_enable;
uniform vec2 Texture_substract_scale = vec2(1.000000, 1.000000);
uniform vec2 Texture_substract_speed;
uniform sampler2D Texture_Substract : source_color, hint_default_black, repeat_enable;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;
uniform float Opacity : hint_range(0.0, 1.0) = 0.0;
uniform bool Use_Fresnel = false;
uniform bool Fresnel_Invert;
uniform float Fresnel_Power = 1.0;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// BooleanParameter:38
	bool n_out38p0 = UseProximityFade;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed;


// Input:24
	float n_out24p0 = support_clock;


// VectorOp:25
	vec2 n_out25p0 = n_out21p0 * vec2(n_out24p0);


// UVFunc:26
	vec2 n_in26p1 = vec2(1.00000, 1.00000);
	vec2 n_out26p0 = n_out25p0 * n_in26p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out26p0);
	float n_out10p1 = n_out10p0.r;


// Vector2Parameter:40
	vec2 n_out40p0 = Texture_substract_scale;


// UVFunc:39
	vec2 n_in39p2 = vec2(0.00000, 0.00000);
	vec2 n_out39p0 = (UV - n_in39p2) * n_out40p0 + n_in39p2;


// Vector2Parameter:41
	vec2 n_out41p0 = Texture_substract_speed;


// Input:42
	float n_out42p0 = support_clock;


// VectorOp:43
	vec2 n_out43p0 = n_out41p0 * vec2(n_out42p0);


// UVFunc:44
	vec2 n_in44p1 = vec2(1.00000, 1.00000);
	vec2 n_out44p0 = n_out43p0 * n_in44p1 + n_out39p0;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Texture_Substract, n_out44p0);
	float n_out19p1 = n_out19p0.r;


// FloatOp:18
	float n_out18p0 = n_out10p1 - n_out19p1;


// Clamp:23
	float n_in23p1 = 0.00000;
	float n_in23p2 = 1.00000;
	float n_out23p0 = clamp(n_out18p0, n_in23p1, n_in23p2);


// SmoothStep:17
	float n_in17p1 = 1.00000;
	float n_out17p0 = smoothstep(n_out4p4, n_in17p1, n_out23p0);


// FloatParameter:13
	float n_out13p0 = Proximity_Fade;


	float n_out12p0;
// ProximityFade:12
	{
		float __depth_tex = texture(depth_tex_frg_12, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out12p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out13p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:11
	float n_out11p0 = n_out17p0 * n_out12p0;


	float n_out37p0;
// Switch:37
	n_out37p0 = mix(n_out17p0, n_out11p0, float(n_out38p0));


// FloatParameter:28
	float n_out28p0 = Opacity;


// FloatOp:27
	float n_out27p0 = n_out37p0 * n_out28p0;


// BooleanParameter:34
	bool n_out34p0 = Use_Fresnel;


// BooleanParameter:32
	bool n_out32p0 = Fresnel_Invert;


// FloatParameter:31
	float n_out31p0 = Fresnel_Power;


// Fresnel:29
	float n_out29p0 = n_out32p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0));


	float n_out33p0;
// Switch:33
	float n_in33p2 = 1.00000;
	n_out33p0 = mix(n_in33p2, n_out29p0, float(n_out34p0));


// FloatOp:30
	float n_out30p0 = n_out27p0 * n_out33p0;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out30p0;



ALPHA *= support_envelope;

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





