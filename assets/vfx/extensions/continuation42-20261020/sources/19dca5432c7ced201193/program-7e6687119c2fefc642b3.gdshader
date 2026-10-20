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

uniform vec2 Texture2_Scale = vec2(1.000000, 1.000000);
uniform vec2 Texture2_pivot = vec2(1.000000, 1.000000);
uniform vec2 Speed_texture = vec2(0.000000, 0.000000);
uniform sampler2D Alpha_Texture : source_color, filter_linear;
uniform vec2 Dissolver_Scale2 = vec2(1.000000, 1.000000);
uniform vec2 Dissolver_pivot2 = vec2(1.000000, 1.000000);
uniform vec2 Speed_disolver = vec2(0.000000, 0.000000);
uniform sampler2D dissolver_texture : source_color, filter_linear;
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool Enable_Proximity_Fade = true;
uniform float ProximityFade = 1.0;
uniform sampler2D depth_tex_frg_44 : hint_depth_texture;
uniform bool Enable_Fresnel = true;
uniform bool Invert_Fresnel;
uniform float Fresnel_power = 0.5;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Input:3
	vec4 n_out3p0 = owned_source_colour;
	float n_out3p4 = n_out3p0.a;


// Vector2Parameter:36
	vec2 n_out36p0 = Texture2_Scale;


// Vector2Parameter:37
	vec2 n_out37p0 = Texture2_pivot;


// UVFunc:30
	vec2 n_out30p0 = (UV - n_out37p0) * n_out36p0 + n_out37p0;


// Input:22
	float n_out22p0 = (vfx_package_seconds()+vfx_package_offset_owned_clock);


// Vector2Parameter:23
	vec2 n_out23p0 = Speed_texture;


// VectorOp:24
	vec2 n_out24p0 = vec2(n_out22p0) * n_out23p0;


// UVFunc:21
	vec2 n_in21p1 = vec2(1.00000, 1.00000);
	vec2 n_out21p0 = n_out24p0 * n_in21p1 + n_out30p0;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Alpha_Texture, n_out21p0);
	float n_out19p1 = n_out19p0.r;


// Vector2Parameter:39
	vec2 n_out39p0 = Dissolver_Scale2;


// Vector2Parameter:38
	vec2 n_out38p0 = Dissolver_pivot2;


// UVFunc:31
	vec2 n_out31p0 = (UV - n_out38p0) * n_out39p0 + n_out38p0;


// Input:25
	float n_out25p0 = (vfx_package_seconds()+vfx_package_offset_owned_clock);


// Vector2Parameter:26
	vec2 n_out26p0 = Speed_disolver;


// VectorOp:29
	vec2 n_out29p0 = vec2(n_out25p0) * n_out26p0;


// UVFunc:28
	vec2 n_in28p1 = vec2(1.00000, 1.00000);
	vec2 n_out28p0 = n_out29p0 * n_in28p1 + n_out31p0;


	vec4 n_out17p0;
// Texture2D:17
	n_out17p0 = texture(dissolver_texture, n_out28p0);
	float n_out17p1 = n_out17p0.r;


// SmoothStep:5
	float n_in5p1 = 1.00000;
	float n_out5p0 = smoothstep(n_out17p1, n_in5p1, n_out3p4);


// FloatOp:7
	float n_out7p0 = n_out19p1 - n_out5p0;


// FloatParameter:51
	float n_out51p0 = Opacity;


// FloatOp:50
	float n_out50p0 = n_out7p0 * n_out51p0;


// Clamp:49
	float n_in49p1 = 0.00000;
	float n_in49p2 = 1.00000;
	float n_out49p0 = clamp(n_out50p0, n_in49p1, n_in49p2);


// BooleanParameter:48
	bool n_out48p0 = Enable_Proximity_Fade;


// FloatParameter:46
	float n_out46p0 = ProximityFade;


	float n_out44p0;
// ProximityFade:44
	{
		float __depth_tex = texture(depth_tex_frg_44, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out44p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out46p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


	float n_out47p0;
// Switch:47
	float n_in47p2 = 1.00000;
	n_out47p0 = mix(n_in47p2, n_out44p0, float(n_out48p0));


// FloatOp:45
	float n_out45p0 = n_out49p0 * n_out47p0;


// BooleanParameter:55
	bool n_out55p0 = Enable_Fresnel;


// BooleanParameter:57
	bool n_out57p0 = Invert_Fresnel;


// FloatParameter:56
	float n_out56p0 = Fresnel_power;


// Fresnel:52
	float n_out52p0 = n_out57p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out56p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out56p0));


	float n_out54p0;
// Switch:54
	float n_in54p2 = 1.00000;
	n_out54p0 = mix(n_in54p2, n_out52p0, float(n_out55p0));


// FloatOp:53
	float n_out53p0 = n_out45p0 * n_out54p0;


// Output:0
	ALBEDO = vec3(n_out3p0.xyz);
	ALPHA = n_out53p0;



	float q_y=UV2.y; float q_x=abs(UV2.x-.5);
	float q_stem=1.0-smoothstep(.025,.055,abs(q_x-(.19+.10*sin(q_y*PI))));
	float q_branch=1.0-smoothstep(.025,.05,min(abs(q_y-(.35+(q_x-.24)*.8)),abs(q_y-(.63+(q_x-.24)*.8))));
	q_branch*=smoothstep(.23,.27,q_x)*(1.0-smoothstep(.40,.45,q_x));
	float q_shape=max(q_stem,q_branch)*smoothstep(.12,.20,q_y)*(1.0-smoothstep(.82,.90,q_y));
	ALPHA=(.24+.76*clamp(ALPHA,0.0,1.0))*q_shape*owned_envelope*.55;
	
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



