shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform mat4 thorns_world_to_source=mat4(1.0);
uniform mat4 thorns_source_to_world=mat4(1.0);uniform float wall_clock=0.0;uniform float wall_fade=1.0;uniform int occupant_count=0;uniform vec4 occupants[16];uniform float contact_pulse=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool split_layers=false;uniform bool foreground=false;uniform float retirement=0.0;uniform float wall_heading=0.0;uniform bool circular=false;
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

void vertex() {vec3 wp=(thorns_world_to_source*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;float anchor=pow(clamp(wp.y/4.242640688,0.0,1.0),1.45);float phase=wall_clock*3.14159265359;float broad=sin(wp.x/33.941125504*6.28318530718*3.0+wp.z*1.1-phase);float tips=sin(wp.x/33.941125504*6.28318530718*7.0+wp.y*1.6+phase*2.0);wp.z+=anchor*(0.23*broad+0.075*tips);wp.x+=anchor*0.08*sin(wp.x/33.941125504*6.28318530718*4.0+wp.y*0.7+phase);wp.y-=anchor*0.065*(0.5+0.5*sin(wp.x/33.941125504*6.28318530718*5.0-phase*2.0));wp.z=1.060660172*tanh(wp.z/1.060660172);if(circular){float theta=wp.x/33.941125504*6.28318530718;float radius=4.242640688+wp.z;wp=vec3(sin(theta)*radius,wp.y,cos(theta)*radius);vec3 wn=MODEL_NORMAL_MATRIX*NORMAL;vec3 curved_n=vec3(cos(theta)*wn.x+sin(theta)*wn.z,wn.y,-sin(theta)*wn.x+cos(theta)*wn.z);NORMAL=normalize(inverse(MODEL_NORMAL_MATRIX)*curved_n);}float ch=cos(wall_heading);float sh=sin(wall_heading);wp.xz=mat2(vec2(ch,-sh),vec2(sh,ch))*wp.xz;wp.y*=1.0-retirement;for(int i=0;i<16;i++){if(i>=occupant_count)break;vec2 offset=wp.xz-occupants[i].xy;float distance=length(offset);float influence=(1.0-smoothstep(0.25,1.45,distance))*occupants[i].z;float body=(1.0-smoothstep(2.0,2.9,wp.y))*smoothstep(0.0,0.45,wp.y);vec2 away=offset/max(distance,0.12);wp.xz+=away*influence*body*(0.32-occupants[i].w*0.58);wp.y-=influence*body*(0.05+0.035*sin(phase*2.0+wp.x));}VERTEX=(inverse(MODEL_MATRIX)*thorns_source_to_world*vec4(wp,1.0)).xyz;}

void fragment() {
	vec2 vine_uv = UV * VineTextureScale;
	vec4 base_color = texture(VinesTexture, vine_uv);


	vec4 gradient_color = texture(EnergyColor2DGradient, UV);
	vec2 noise_uv = (UV * NoiseScale) + (NoiseSpeed * 0.0);
	vec3 detail_noise = texture(DetailsNoiseTexture, noise_uv).rgb;
	vec3 energy_base = gradient_color.rgb * detail_noise;

	vec2 dissolve_uv = (UV * DisolverDetailsScale) + (DisolverDetailsSpeed * wall_clock);
	float dissolve_noise = texture(DisolverDetailsTexture, dissolve_uv).r;
	float dissolve_mask = UV.g;

	float combined_dissolve = mix(dissolve_mask,dissolve_noise,DisolverDetails);

	float dissolve_step_high = step(combined_dissolve, DisolverSTEP + DisolverBaias);
	float current_energy = (dissolve_step_high * 0.0) + Intensity;
	vec3 final_energy = energy_base * current_energy;

	float fresnel_dot = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel_base = IsInvertFresnel ? fresnel_dot : (1.0 - fresnel_dot);
	float fresnel_val = pow(fresnel_base, FresnelPower);

	vec3 final_color = mix(base_color.rgb, final_energy, fresnel_val);

	ALBEDO = final_color;
	ALPHA = step(DisolverSTEP, combined_dissolve);
	ROUGHNESS = Roughtness;
	ALPHA_SCISSOR_THRESHOLD = AlphaScissorThreshold;
vec3 contact_surface=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;ALPHA*=wall_fade;
ALPHA *= factory_occurrence_alpha;
}


