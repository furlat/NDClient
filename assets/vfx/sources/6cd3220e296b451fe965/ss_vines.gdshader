shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx;


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
instance uniform float DisolverSTEP : hint_range(-0.2, 1.0) = 0.0;
uniform float DisolverBaias = 0.05;
instance uniform float DisolverDetails :hint_range(0.0, 1.0, 0.01)= 0.2;

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
	vec2 moving_uv = (UV * VertexScale) + (VertexSpeed * TIME);
	float vert_noise = texture(TextureVertex, moving_uv).r;
	float vert_mask = UV.g;
	float surface_pulse = vert_noise * vert_mask * VertexIntensity;

	float time_offset = COLOR.r * 6.28318;

	// COLOR.g and COLOR.b are mapped from [0, 1] to [-1, 1] to allow swaying in negative directions
	vec3 vertex_color_dir = vec3((COLOR.g * 2.0) - 1.0, 0.0, (COLOR.b * 2.0) - 1.0);

	vec3 final_sway_dir = normalize(mix(SwayDirection, vertex_color_dir, SwayRandomness));

	float sway_wave = sin((VERTEX.y * SwayFrequency) + (TIME * SwaySpeed + time_offset));
	vec3 sway_displacement = final_sway_dir * sway_wave * SwayAmplitude * (1.0-vert_mask);

	VERTEX += (NORMAL * surface_pulse) + sway_displacement;
}

void fragment() {
	vec2 vine_uv = UV * VineTextureScale;
	vec4 base_color = texture(VinesTexture, vine_uv);


	vec4 gradient_color = texture(EnergyColor2DGradient, UV);
	vec2 noise_uv = (UV * NoiseScale) + (NoiseSpeed * TIME);
	vec3 detail_noise = texture(DetailsNoiseTexture, noise_uv).rgb;
	vec3 energy_base = gradient_color.rgb * detail_noise;

	vec2 dissolve_uv = (UV * DisolverDetailsScale) + (DisolverDetailsSpeed * TIME);
	float dissolve_noise = texture(DisolverDetailsTexture, dissolve_uv).r;
	float dissolve_mask = UV.g;

	float combined_dissolve = mix(dissolve_mask,dissolve_noise,DisolverDetails);

	float dissolve_step_high = step(combined_dissolve, DisolverSTEP + DisolverBaias);
	float current_energy = (dissolve_step_high * DisolverColorEnergy) + Intensity;
	vec3 final_energy = energy_base * current_energy;

	float fresnel_dot = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel_base = IsInvertFresnel ? fresnel_dot : (1.0 - fresnel_dot);
	float fresnel_val = pow(fresnel_base, FresnelPower);

	vec3 final_color = mix(base_color.rgb, final_energy, fresnel_val);

	ALBEDO = final_color;
	ALPHA = step(DisolverSTEP, combined_dissolve);
	ROUGHNESS = Roughtness;
	ALPHA_SCISSOR_THRESHOLD = AlphaScissorThreshold;
}