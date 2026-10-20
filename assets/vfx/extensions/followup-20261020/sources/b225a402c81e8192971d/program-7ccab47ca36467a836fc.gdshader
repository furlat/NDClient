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
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled;

uniform float Intensity = 1.0;
uniform bool EnableBlinkin = false;
uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Texture : source_color, repeat_enable;
uniform sampler2D Add_Texture : source_color, hint_default_black, filter_linear;
uniform sampler2D Multiply_Texture : source_color, filter_linear;
uniform float Blinking_speed = 0.0;
uniform float min_brightness = 0.5;
uniform float max_brightness2 = 1.0;
uniform sampler2D Color_gradient_1D : source_color, repeat_disable;
uniform bool Enable_Proximity_Fade = true;
uniform float Proximity_Fade = 0.10000000149012;
uniform sampler2D depth_tex_frg_32 : hint_depth_texture;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;



void vertex() {
	mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __mvm = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
		__mvm = __mvm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = __mvm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;


}

void fragment() {
// FloatParameter:30
	float n_out30p0 = Intensity;


// BooleanParameter:26
	bool n_out26p0 = EnableBlinkin;


// Vector2Parameter:5
	vec2 n_out5p0 = Scale;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (UV - n_in4p2) * n_out5p0 + n_in4p2;


// Input:10
	float n_out10p0 = support_clock;


// Vector2Parameter:12
	vec2 n_out12p0 = Velocity;


// VectorOp:11
	vec2 n_out11p0 = vec2(n_out10p0) * n_out12p0;


// UVFunc:9
	vec2 n_in9p1 = vec2(1.00000, 1.00000);
	vec2 n_out9p0 = n_out11p0 * n_in9p1 + n_out4p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Texture, n_out9p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Add_Texture, UV);
	float n_out15p1 = n_out15p0.r;


// FloatOp:16
	float n_out16p0 = n_out3p1 + n_out15p1;


	vec4 n_out7p0;
// Texture2D:7
	n_out7p0 = texture(Multiply_Texture, UV);
	float n_out7p1 = n_out7p0.r;


// FloatOp:8
	float n_out8p0 = n_out16p0 * n_out7p1;


// Clamp:13
	float n_in13p1 = 0.00000;
	float n_in13p2 = 1.00000;
	float n_out13p0 = clamp(n_out8p0, n_in13p1, n_in13p2);


// Input:17
	float n_out17p0 = support_clock;


// FloatParameter:19
	float n_out19p0 = Blinking_speed;


// FloatOp:18
	float n_out18p0 = n_out17p0 * n_out19p0;


// FloatFunc:20
	float n_out20p0 = cos(n_out18p0);


// FloatParameter:22
	float n_out22p0 = min_brightness;


// FloatParameter:23
	float n_out23p0 = max_brightness2;


	float n_out21p0;
// Remap:21
	float n_in21p1 = -1.00000;
	float n_in21p2 = 1.00000;
	{
		float __input_range = n_in21p2 - n_in21p1;
		float __output_range = n_out23p0 - n_out22p0;
		n_out21p0 = n_out22p0 + __output_range * ((n_out20p0 - n_in21p1) / __input_range);
	}


// FloatOp:24
	float n_out24p0 = n_out13p0 * n_out21p0;


	float n_out25p0;
// Switch:25
	n_out25p0 = mix(n_out13p0, n_out24p0, float(n_out26p0));


	vec4 n_out28p0;
// Texture2D:28
	n_out28p0 = texture(Color_gradient_1D, vec2(n_out25p0));
	float n_out28p4 = n_out28p0.a;


// VectorOp:31
	vec3 n_out31p0 = vec3(n_out30p0) * vec3(n_out28p0.xyz);


// BooleanParameter:36
	bool n_out36p0 = Enable_Proximity_Fade;


// FloatParameter:34
	float n_out34p0 = Proximity_Fade;


	float n_out32p0;
// ProximityFade:32
	{
		float __depth_tex = texture(depth_tex_frg_32, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out32p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out34p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:33
	float n_out33p0 = n_out28p4 * n_out32p0;


	float n_out35p0;
// Switch:35
	n_out35p0 = mix(n_out28p4, n_out33p0, float(n_out36p0));


// FloatParameter:38
	float n_out38p0 = Opacity;


// FloatOp:37
	float n_out37p0 = n_out35p0 * n_out38p0;


// Output:0
	ALBEDO = n_out31p0;
	ALPHA = n_out37p0;



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







