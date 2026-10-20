shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_moon_clock=0.0;

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
varying float moon_height;
uniform float moon_clock=0.0;
uniform float moon_opacity=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform float Color_Intensity = 1.0;
uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_Texture : source_color;
uniform sampler2D Add_Texture : source_color, repeat_disable;
uniform sampler2D Substract_Texture : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_1D_Color : source_color;
uniform float Dissolver_edge : hint_range(0.0, 1.0) = 0.0;
uniform bool Fresnel_Invert = false;
uniform float Fresnel_Power = 1.0;



void fragment() {
// FloatParameter:27
	float n_out27p0 = Color_Intensity;


// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:10
	vec2 n_out10p0 = Speed_XY;


// Input:12
	float n_out12p0 = (vfx_package_seconds()+vfx_package_offset_moon_clock);


// VectorOp:11
	vec2 n_out11p0 = n_out10p0 * vec2(n_out12p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out11p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_Texture, n_out8p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out6p0;
// Texture2D:6
	n_out6p0 = texture(Add_Texture, UV);
	float n_out6p1 = n_out6p0.r;


// FloatOp:24
	float n_out24p0 = n_out3p1 + n_out6p1;


	vec4 n_out34p0;
// Texture2D:34
	n_out34p0 = texture(Substract_Texture, UV);
	float n_out34p1 = n_out34p0.r;


// FloatOp:36
	float n_out36p0 = n_out24p0 - n_out34p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out36p0, n_in25p1, n_in25p2);


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Gradient_1D_Color, vec2(n_out25p0));
	float n_out15p4 = n_out15p0.a;


// VectorOp:26
	vec3 n_out26p0 = vec3(n_out27p0) * vec3(n_out15p0.xyz);


// FloatParameter:29
	float n_out29p0 = Dissolver_edge;


// SmoothStep:28
	float n_in28p1 = 1.00000;
	float n_out28p0 = smoothstep(n_out29p0, n_in28p1, n_out15p4);


// BooleanParameter:33
	bool n_out33p0 = Fresnel_Invert;


// FloatParameter:32
	float n_out32p0 = Fresnel_Power;


// Fresnel:31
	float n_out31p0 = n_out33p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out32p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out32p0));


// FloatOp:30
	float n_out30p0 = n_out28p0 * n_out31p0;


// Output:0
	ALBEDO = n_out26p0;
	ALPHA = n_out30p0;



ALPHA *= moon_opacity;

ALPHA *= smoothstep(0.0,0.12,moon_height)*(1.0-smoothstep(0.75,1.0,moon_height));
float moon_facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
ALPHA*=smoothstep(0.0,0.42,moon_facing)*smoothstep(0.08,0.34,ALPHA);

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


void vertex(){moon_height=VERTEX.y;}


