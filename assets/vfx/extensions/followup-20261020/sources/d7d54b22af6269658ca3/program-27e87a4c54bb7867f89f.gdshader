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
uniform float curse_sector=0.0;

render_mode unshaded, cull_disabled, blend_add;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0,0.8,0.2);
uniform vec3 secondary_color : source_color = vec3(1.0,0.4,0.1);
uniform vec3 tertiary_color : source_color = vec3(0.6,0.1,0.05);
uniform float emission = 2.0;
uniform float hue_variation = 0.0;
uniform float color_curve = 1.0;

group_uniforms Shape;
uniform sampler2D noise_texture;
uniform vec2 noise_scale = vec2(3.0, 1.0);
uniform vec2 noise_scroll = vec2(0.1, 0.4);
uniform float noise_twist : hint_range(-1.0, 1.0, 0.05) = 1.0;
uniform float shape_curve = 2.0;
uniform float waviness : hint_range(0.0, 1.0, 0.01) = 0.2;

group_uniforms Transparency;
uniform float edge_hardness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_position : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform bool proximity_fade = false;
uniform float proximity_fade_distance : hint_range(0.0, 4096.0, 0.01);
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

vec3 shift_hue(vec3 color, float shift) {
	vec3 gray = vec3(0.57735);
	vec3 projection = gray * dot(gray, color.rgb);
	vec3 U = color.rgb - projection;
	vec3 V = cross(gray, U);
	vec3 shifted = U * cos(shift * 2.0 * PI) + V * sin(shift * 2.0 * PI) + projection;
	return shifted;
}

float sample_value(vec2 uv){
	vec2 noise_uv = vec2(uv.x - uv.y * noise_twist, uv.y) * noise_scale + (support_clock * noise_scroll);
	float noise = texture(noise_texture, noise_uv).r;
	
	float mask = pow(max((1.0 - abs(uv.y * 2.0 - 1.0) - 0.5) / 0.5, 0.0), 0.2); 
	
	float value = max(noise * mask, 0.0);
	value = smoothstep(0.5, 0.8, value);
	
	return value;
}

void fragment() {
float segment=fract(UV.x + UV.y*0.045)*8.0; if(floor(segment)!=curse_sector || fract(segment)<0.12 || fract(segment)>0.88) discard;

	
	float wave = sin(UV.y * 40.0 - support_clock * 1.0);
	
	float value = sample_value(UV + vec2(wave * 0.1 * waviness, 0.0));
	
	vec3 color = mix(secondary_color, primary_color, value);
	
	if(!FRONT_FACING){
		color = tertiary_color;
	}
	float hue_wave = sin(UV.x * TAU * 4.0 + support_clock) + sin(UV.y * TAU * 5.0 + support_clock);
	color = shift_hue(color, hue_wave * hue_variation);
	
	ALBEDO = color * emission;
	
	ALPHA = value;
	
	// Proximity Fade: Enabled
	if(proximity_fade){
		float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec4 ndc = OUTPUT_IS_SRGB ? vec4(vec3(SCREEN_UV, proximity_depth_tex) * 2.0 - 1.0, 1.0) : vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * ndc;
		proximity_view_pos.xyz /= proximity_view_pos.w;
		ALPHA *= clamp(1.0 - smoothstep(proximity_view_pos.z + proximity_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	}
	
	ALPHA = clamp((ALPHA - edge_position) / (1.0 - edge_hardness), 0.0, 1.0);

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
	
	float peel_age=smoothstep(0.18,0.95,support_clock);
	vec2 peel_uv=vec2(UV.x-UV.y*noise_twist,UV.y)*noise_scale+support_clock*noise_scroll;
	float peel_noise=texture(noise_texture,peel_uv*vec2(1.7,2.3)).r;
	float peel_cut=mix(0.08,0.88,peel_age);
	ALPHA*=smoothstep(peel_cut,peel_cut+0.14,peel_noise);
	ALPHA*=1.0-smoothstep(0.65,1.25,support_clock);
	}




