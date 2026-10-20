shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_wisp_clock=0.0;

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
uniform float wisp_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_prepass_alpha, unshaded;

uniform sampler2D Base_noise2 : source_color, repeat_enable;
uniform vec2 Speed_XY2;
uniform vec2 Scale_XY2 = vec2(1.000000, 1.000000);
uniform bool Fresnel_Invert = false;
uniform float Fresnel_power = 1.0;
uniform sampler2D Fresnel_Gradient_Color_1D : source_color, repeat_disable;
uniform sampler2D Texture_substract : source_color, hint_default_black, repeat_disable;
uniform sampler2D Texture_add : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_Color_1D2 : source_color, repeat_disable;
uniform float Color_Intensity2 = 1.0;
uniform sampler2D Texture_substract_end : source_color, hint_default_black, repeat_disable;



void fragment() {
// Vector2Parameter:43
	vec2 n_out43p0 = Scale_XY2;


// UVFunc:39
	vec2 n_in39p2 = vec2(0.00000, 0.00000);
	vec2 n_out39p0 = (UV - n_in39p2) * n_out43p0 + n_in39p2;


// Vector2Parameter:41
	vec2 n_out41p0 = Speed_XY2;


// Input:40
	float n_out40p0 = (vfx_package_seconds()+vfx_package_offset_wisp_clock);


// VectorOp:42
	vec2 n_out42p0 = n_out41p0 * vec2(n_out40p0);


// UVFunc:38
	vec2 n_in38p1 = vec2(1.00000, 1.00000);
	vec2 n_out38p0 = n_out42p0 * n_in38p1 + n_out39p0;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Base_noise2, n_out38p0);
	float n_out33p1 = n_out33p0.r;


// BooleanParameter:23
	bool n_out23p0 = Fresnel_Invert;


// FloatParameter:22
	float n_out22p0 = Fresnel_power;


// Fresnel:21
	float n_out21p0 = n_out23p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out22p0));


	vec4 n_out52p0;
// Texture2D:52
	n_out52p0 = texture(Fresnel_Gradient_Color_1D, vec2(n_out21p0));
	float n_out52p1 = n_out52p0.r;


// FloatOp:14
	float n_out14p0 = n_out33p1 + n_out52p1;


	vec4 n_out36p0;
// Texture2D:36
	n_out36p0 = texture(Texture_substract, UV);
	float n_out36p1 = n_out36p0.r;


// FloatOp:45
	float n_out45p0 = n_out14p0 * n_out36p1;


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Texture_add, UV);
	float n_out35p1 = n_out35p0.r;


// FloatOp:44
	float n_out44p0 = n_out45p0 + n_out35p1;


// Clamp:46
	float n_in46p1 = 0.00000;
	float n_in46p2 = 1.00000;
	float n_out46p0 = clamp(n_out44p0, n_in46p1, n_in46p2);


	vec4 n_out48p0;
// Texture2D:48
	n_out48p0 = texture(Gradient_Color_1D2, vec2(n_out46p0));
	float n_out48p4 = n_out48p0.a;


// FloatParameter:50
	float n_out50p0 = Color_Intensity2;


// VectorOp:49
	vec3 n_out49p0 = vec3(n_out48p0.xyz) * vec3(n_out50p0);


	vec4 n_out54p0;
// Texture2D:54
	n_out54p0 = texture(Texture_substract_end, UV);
	float n_out54p1 = n_out54p0.r;


// FloatOp:55
	float n_out55p0 = n_out48p4 * n_out54p1;


// Clamp:57
	float n_in57p1 = 0.00000;
	float n_in57p2 = 1.00000;
	float n_out57p0 = clamp(n_out55p0, n_in57p1, n_in57p2);


// Output:0
	ALBEDO = n_out49p0;
	ALPHA = n_out57p0;



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





