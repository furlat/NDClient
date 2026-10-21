shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_vfx_clock=0.0;

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


uniform float vfx_clock=0.0;
uniform float vfx_alpha=0.0;
uniform sampler2D original_palette:filter_nearest,repeat_disable;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform float Size_Sphere = 0.0;
uniform float Gradient_Line : hint_range(0.0, 0.83999997377396) = 0.0;
uniform float Line_Baias = 0.01999999955297;
uniform float SmoothStep : hint_range(0.0, 1.0) = 0.80000001192093;
uniform vec2 Disolver_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Noise_Line : source_color, filter_linear, repeat_enable;
uniform float Line_Distortion_Divider = 5.0;
uniform sampler2D Gradient_Disappear : source_color, filter_linear, repeat_disable;
uniform sampler2D Line_Gradient : source_color, filter_linear, repeat_disable;
uniform vec2 Overlay_Scale = vec2(1.000000, 1.000000);
uniform vec2 Overlay_Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Overlay_Texture : source_color, hint_default_black, filter_linear;
uniform float Overlay_Power = 2.0;
uniform float Proximity_light = 0.5;
uniform sampler2D depth_tex_frg_31 : hint_depth_texture;
uniform float Proximity_Power = 0.5;
uniform bool Fresnel_invert;
uniform float fresnel_power = 0.68300002813339;
uniform float darkness = 0.0;
uniform sampler2D Gradient_1D_Color : source_color, filter_linear;



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:4
	vec3 n_out4p0 = NORMAL;


// FloatParameter:6
	float n_out6p0 = Size_Sphere;


// VectorOp:5
	vec3 n_out5p0 = n_out4p0 * vec3(n_out6p0);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
if(!((UV.x > 0.04 && UV.x < 0.24) || (UV.x > 0.53 && UV.x < 0.79)) || UV.y < 0.20 || UV.y > 0.80) discard;

// FloatParameter:56
	float n_out56p0 = Gradient_Line;


// FloatParameter:61
	float n_out61p0 = Line_Baias;


// FloatOp:59
	float n_out59p0 = n_out56p0 - n_out61p0;


// FloatParameter:95
	float n_out95p0 = SmoothStep;


// Input:78
	vec2 n_out78p0 = UV;


// Vector2Parameter:83
	vec2 n_out83p0 = Disolver_Scale;


// UVFunc:82
	vec2 n_in82p2 = vec2(0.00000, 0.00000);
	vec2 n_out82p0 = (UV - n_in82p2) * n_out83p0 + n_in82p2;


	vec4 n_out77p0;
// Texture2D:77
	n_out77p0 = texture(Disolver_Noise_Line, n_out82p0);
	float n_out77p1 = n_out77p0.r;


// FloatParameter:91
	float n_out91p0 = Line_Distortion_Divider;


// FloatOp:80
	float n_out80p0 = n_out77p1 / n_out91p0;


// VectorOp:79
	vec2 n_out79p0 = n_out78p0 + vec2(n_out80p0);


	vec4 n_out86p0;
// Texture2D:86
	n_out86p0 = texture(Gradient_Disappear, n_out79p0);
	float n_out86p1 = n_out86p0.r;


// FloatOp:94
	float n_in94p1 = 0.59000;
	float n_out94p0 = pow(n_out86p1, n_in94p1);


// SmoothStep:84
	float n_out84p0 = smoothstep(n_out59p0, n_out95p0, n_out94p0);


	vec4 n_out90p0;
// Texture2D:90
	n_out90p0 = texture(Line_Gradient, vec2(n_out84p0));


// Input:50
	vec2 n_out50p0 = UV;


// Vector2Parameter:43
	vec2 n_out43p0 = Overlay_Scale;


// UVFunc:42
	vec2 n_in42p2 = vec2(0.00000, 0.00000);
	vec2 n_out42p0 = (n_out50p0 - n_in42p2) * n_out43p0 + n_in42p2;


// Vector2Parameter:44
	vec2 n_out44p0 = Overlay_Velocity;


// Input:47
	float n_out47p0 = (vfx_package_seconds()+vfx_package_offset_vfx_clock);


// VectorOp:45
	vec2 n_out45p0 = n_out44p0 * vec2(n_out47p0);


// UVFunc:46
	vec2 n_in46p1 = vec2(1.00000, 1.00000);
	vec2 n_out46p0 = n_out45p0 * n_in46p1 + n_out42p0;


	vec4 n_out41p0;
// Texture2D:41
	n_out41p0 = texture(Overlay_Texture, n_out46p0);
	float n_out41p1 = n_out41p0.r;


// FloatParameter:49
	float n_out49p0 = Overlay_Power;


// FloatOp:48
	float n_out48p0 = pow(n_out41p1, n_out49p0);


// FloatParameter:34
	float n_out34p0 = Proximity_light;


	float n_out31p0;
// ProximityFade:31
	{
		float __depth_tex = texture(depth_tex_frg_31, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out31p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out34p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatParameter:36
	float n_out36p0 = Proximity_Power;


// FloatOp:35
	float n_out35p0 = pow(n_out31p0, n_out36p0);


// FloatFunc:33
	float n_out33p0 = 1.0 - n_out35p0;


// BooleanParameter:19
	bool n_out19p0 = Fresnel_invert;


// FloatParameter:14
	float n_out14p0 = fresnel_power;


// Fresnel:11
	float n_out11p0 = n_out19p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out14p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out14p0));


// FloatOp:32
	float n_out32p0 = n_out33p0 + n_out11p0;


// FloatOp:39
	float n_out39p0 = n_out48p0 + n_out32p0;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out39p0, n_in25p1, n_in25p2);


// FloatParameter:15
	float n_out15p0 = darkness;


// FloatOp:13
	float n_out13p0 = n_out25p0 - n_out15p0;


// FloatOp:97
	float n_out97p0 = n_out84p0 + n_out13p0;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Gradient_1D_Color, vec2(n_out97p0));
	float n_out38p4 = n_out38p0.a;


// VectorOp:63
	vec3 n_out63p0 = vec3(n_out90p0.xyz) + vec3(n_out38p0.xyz);


// Step:57
	float n_out57p0 = step(n_out86p1, n_out56p0);


// FloatOp:96
	float n_out96p0 = n_out38p4 * n_out57p0;


// Output:0
	ALBEDO = n_out63p0;
	ALPHA = n_out96p0;



ALPHA=max(ALPHA,(0.42+smoothstep(0.30,0.68,n_out77p0.r)*0.43))*vfx_alpha; float strength=clamp(n_out77p0.r*0.9+length(ALBEDO)*0.15,0.0,1.0); ALBEDO=mix(vec3(0.35,0.10,0.12),vec3(0.95,0.42,0.32),strength);
vec3 original_encoded=cie_nearest(clamp(ALBEDO*1.08,vec3(0.0),vec3(1.0)),original_palette,4,0.0,0.0); ALBEDO=vec3(cie_linear_channel(original_encoded.r),cie_linear_channel(original_encoded.g),cie_linear_channel(original_encoded.b)); EMISSION=vec3(0.0);
}


