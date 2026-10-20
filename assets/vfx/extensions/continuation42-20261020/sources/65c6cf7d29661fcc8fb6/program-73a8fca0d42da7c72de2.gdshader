shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_owned_clock=0.0;

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
uniform float owned_clock=0.0;
uniform float owned_envelope=0.0;
uniform vec4 owned_source_colour=vec4(0.0,0.5,0.5,1.0);

render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec4 Line_Color : source_color;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform sampler2D Texture : source_color, repeat_disable;
uniform sampler2D Gradient_1D_texture : source_color, filter_linear;
uniform float Line_Thickness = 0.0;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_12 : hint_depth_texture;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// ColorParameter:22
	vec4 n_out22p0 = Line_Color;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out15p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Gradient_1D_texture, vec2(n_out10p1));


// Input:4
	vec4 n_out4p0 = owned_source_colour;
	float n_out4p4 = n_out4p0.a;


// FloatParameter:23
	float n_out23p0 = Line_Thickness;


// FloatOp:20
	float n_out20p0 = n_out4p4 + n_out23p0;


// Step:19
	float n_out19p0 = step(n_out20p0, n_out10p1);


// Mix:21
	vec3 n_out21p0 = mix(vec3(n_out22p0.xyz), vec3(n_out18p0.xyz), n_out19p0);


// Step:14
	float n_out14p0 = step(n_out4p4, n_out10p1);


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
	float n_out11p0 = n_out14p0 * n_out12p0;


// Output:0
	ALBEDO = n_out21p0;
	ALPHA = n_out11p0;



ALPHA=(.24+.76*n_out14p0)*sin(UV.x*PI)*sin(UV.y*PI)*owned_envelope*.45;

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



