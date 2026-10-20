shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

varying flat vec4 plant_native_state;
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
uniform float growth_clock_seconds=0.0;
uniform float cue_opacity=1.0;

render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx;


group_uniforms Colors;
uniform vec2 VineTextureScale = vec2(1.0, 1.0);
uniform sampler2D VinesTexture : source_color, hint_default_black;

uniform sampler2D EnergyColor2DGradient : source_color;
uniform vec2 NoiseScale = vec2(1.0, 1.0);
uniform vec2 NoiseSpeed = vec2(0.0, 0.0);
uniform sampler2D DetailsNoiseTexture : source_color, repeat_enable;

uniform float Intensity = 1.0;
uniform float DisolverColorEnergy = 100.0;
uniform bool  IsInvertFresnel = false;
uniform float FresnelPower = 1.0;
uniform float Roughtness : hint_range(0.0, 1.0) = 1.0;
uniform float AlphaScissorThreshold : hint_range(0.0, 1.0) = 0.5;


group_uniforms DesintegrationStuff;
uniform vec2 DisolverDetailsScale = vec2(1.0, 1.0);
uniform vec2 DisolverDetailsSpeed = vec2(0.0, 0.0);
uniform sampler2D DisolverDetailsTexture : source_color, repeat_enable;

uniform float DisolverBaias = 0.05;
uniform float DisolverDetails :hint_range(0.0, 1.0, 0.01)= 0.2;

group_uniforms Movement;
uniform vec2 VertexScale = vec2(1.0, 1.0);
uniform vec2 VertexSpeed = vec2(0.0, 0.0);
uniform float VertexIntensity = 0.3;
uniform sampler2D TextureVertex : source_color, hint_default_black, repeat_enable;

// Tentacle Sway (Overall Movement)
uniform float SwaySpeed = 3.0;
uniform float SwayFrequency = 2.0;
uniform float SwayAmplitude = 0.5;
uniform vec3 SwayDirection = vec3(1.0, 0.0, 1.0);
uniform float SwayRandomness : hint_range(0.0, 1.0) = 1.0; // 0 = use uniform direction, 1 = use Vertex Colors

void vertex() {
plant_native_state=INSTANCE_CUSTOM;

	vec2 moving_uv = (UV * VertexScale) + (VertexSpeed * growth_clock_seconds);
	float vert_noise = texture(TextureVertex, moving_uv).r;
	float vert_mask = UV.g;
	float surface_pulse = vert_noise * vert_mask * VertexIntensity;

	float time_offset = COLOR.r * 6.28318;

	// COLOR.g and COLOR.b are mapped from [0, 1] to [-1, 1] to allow swaying in negative directions
	vec3 vertex_color_dir = vec3((COLOR.g * 2.0) - 1.0, 0.0, (COLOR.b * 2.0) - 1.0);

	vec3 final_sway_dir = normalize(mix(SwayDirection, vertex_color_dir, SwayRandomness));

	float sway_wave = sin((VERTEX.y * SwayFrequency) + (growth_clock_seconds * SwaySpeed + time_offset));
	vec3 sway_displacement = final_sway_dir * sway_wave * SwayAmplitude * (1.0-vert_mask);

	VERTEX += (NORMAL * surface_pulse) + sway_displacement;

mat3 plant_basis=mat3(MODELVIEW_MATRIX);if(determinant(plant_basis)!=0.0){MODELVIEW_NORMAL_MATRIX=transpose(inverse(plant_basis));}
}

void fragment() {
if(plant_native_state.z<.5)discard;

	vec2 vine_uv = UV * VineTextureScale;
	vec4 base_color = texture(VinesTexture, vine_uv);


	vec4 gradient_color = texture(EnergyColor2DGradient, UV);
	vec2 noise_uv = (UV * NoiseScale) + (NoiseSpeed * growth_clock_seconds);
	vec3 detail_noise = texture(DetailsNoiseTexture, noise_uv).rgb;
	vec3 energy_base = gradient_color.rgb * detail_noise;

	vec2 dissolve_uv = (UV * DisolverDetailsScale) + (DisolverDetailsSpeed * growth_clock_seconds);
	float dissolve_noise = texture(DisolverDetailsTexture, dissolve_uv).r;
	float dissolve_mask = UV.g;

	float combined_dissolve = mix(dissolve_mask,dissolve_noise,DisolverDetails);

	float dissolve_step_high = step(combined_dissolve, plant_native_state.x + DisolverBaias);
	float current_energy = (dissolve_step_high * DisolverColorEnergy) + Intensity;
	vec3 final_energy = energy_base * current_energy;

	float fresnel_dot = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel_base = IsInvertFresnel ? fresnel_dot : (1.0 - fresnel_dot);
	float fresnel_val = pow(fresnel_base, FresnelPower);

	vec3 final_color = mix(base_color.rgb, final_energy, fresnel_val);

	ALBEDO = final_color;
	ALPHA = step(plant_native_state.x, combined_dissolve);
	ROUGHNESS = Roughtness;
	ALPHA_SCISSOR_THRESHOLD = AlphaScissorThreshold;

ALPHA *= cue_opacity;

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




