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

float branding_segment(vec2 p,vec2 a,vec2 b) {
 vec2 d=b-a;
 float t=clamp(dot(p-a,d)/dot(d,d),0.0,1.0);
 return 1.0-smoothstep(.025,.065,length(p-a-d*t));
}
float branding_mark(vec2 p) {
 // Open interlocking strokes leave the original receiving body readable.
 float mark=branding_segment(p,vec2(.24,.26),vec2(.69,.63));
 mark=max(mark,branding_segment(p,vec2(.76,.26),vec2(.31,.63)));
 mark=max(mark,branding_segment(p,vec2(.32,.73),vec2(.68,.73)));
 return mark*(.86+.08*sin(smite_clock*1.1));
}

render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform bool Enable_Distortion;
uniform vec2 distortion_scale = vec2(1.000000, 1.000000);
uniform vec2 distortion_speed = vec2(1.000000, 1.000000);
uniform sampler2D DistortionTexture : hint_normal, filter_linear;
uniform float DistortionStregnht = 0.01999999955297;
uniform vec2 scale = vec2(1.000000, 1.000000);
uniform vec2 speed = vec2(1.000000, 1.000000);
uniform sampler2D BaseTexture : source_color, repeat_enable;
uniform sampler2D Multiply_Mask : source_color, repeat_disable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform bool Use_Proximity_Fade = false;
uniform float Proximity_Fade = 0.5;
uniform sampler2D depth_tex_frg_109 : hint_depth_texture;



void vertex() {}
void fragment() {
// Input:104
	vec4 n_out104p0 = smite_source_colour;


// BooleanParameter:113
	bool n_out113p0 = Enable_Distortion;


// Input:114
	vec2 n_out114p0 = UV;


// Vector2Parameter:10
	vec2 n_out10p0 = distortion_scale;


// UVFunc:17
	vec2 n_in17p2 = vec2(0.00000, 0.00000);
	vec2 n_out17p0 = (UV - n_in17p2) * n_out10p0 + n_in17p2;


// Input:7
	float n_out7p0 = smite_clock;


// Vector2Parameter:8
	vec2 n_out8p0 = distortion_speed;


// VectorOp:9
	vec2 n_out9p0 = vec2(n_out7p0) * n_out8p0;


// UVFunc:6
	vec2 n_in6p1 = vec2(1.00000, 1.00000);
	vec2 n_out6p0 = n_out9p0 * n_in6p1 + n_out17p0;


	vec4 n_out12p0;
// Texture2D:12
	n_out12p0 = texture(DistortionTexture, n_out6p0);
	float n_out12p1 = n_out12p0.r;
	float n_out12p2 = n_out12p0.g;


// VectorCompose:3
	vec2 n_out3p0 = vec2(n_out12p1, n_out12p2);


// FloatParameter:19
	float n_out19p0 = DistortionStregnht;


// VectorOp:15
	vec2 n_out15p0 = n_out3p0 * vec2(n_out19p0);


// VectorOp:13
	vec2 n_out13p0 = n_out114p0 - n_out15p0;


// Input:112
	vec2 n_out112p0 = UV;


	vec2 n_out111p0;
// Switch:111
	n_out111p0 = mix(n_out112p0, n_out13p0, float(n_out113p0));


// Vector2Parameter:98
	vec2 n_out98p0 = scale;


// UVFunc:97
	vec2 n_in97p2 = vec2(0.00000, 0.00000);
	vec2 n_out97p0 = (n_out111p0 - n_in97p2) * n_out98p0 + n_in97p2;


// Input:94
	float n_out94p0 = smite_clock;


// Vector2Parameter:95
	vec2 n_out95p0 = speed;


// VectorOp:96
	vec2 n_out96p0 = vec2(n_out94p0) * n_out95p0;


// UVFunc:93
	vec2 n_in93p1 = vec2(1.00000, 1.00000);
	vec2 n_out93p0 = n_out96p0 * n_in93p1 + n_out97p0;


	vec4 n_out92p0;
// Texture2D:92
	n_out92p0 = texture(BaseTexture, n_out93p0);
	float n_out92p1 = n_out92p0.r;


	vec4 n_out102p0;
// Texture2D:102
	n_out102p0 = texture(Multiply_Mask, UV);
	float n_out102p1 = n_out102p0.r;


// FloatOp:103
	float n_out103p0 = n_out92p1 * n_out102p1;


	vec4 n_out100p0;
// Texture2D:100
	n_out100p0 = texture(Color1DGradient, vec2(n_out103p0));


// VectorOp:105
	vec4 n_out105p0 = n_out104p0 * n_out100p0;
	float n_out105p4 = n_out105p0.a;


// BooleanParameter:108
	bool n_out108p0 = Use_Proximity_Fade;


// FloatParameter:110
	float n_out110p0 = Proximity_Fade;


	float n_out109p0;
// ProximityFade:109
	{
		float __depth_tex = texture(depth_tex_frg_109, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out109p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out110p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:106
	float n_out106p0 = n_out105p4 * n_out109p0;


	float n_out107p0;
// Switch:107
	n_out107p0 = mix(n_out105p4, n_out106p0, float(n_out108p0));


// Output:0
	ALBEDO = vec3(n_out105p0.xyz);
	ALPHA = n_out107p0;



ALPHA=(.35+.65*clamp(ALPHA,0.0,1.0))*branding_mark(UV2)*smite_envelope*.60;

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



