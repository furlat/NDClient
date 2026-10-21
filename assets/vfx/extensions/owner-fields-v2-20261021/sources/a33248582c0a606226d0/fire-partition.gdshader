shader_type spatial;
varying vec2 observed_local_xz;
uniform sampler2D observed_perimeter_texture;
uniform vec2 observed_cells[128];
uniform float observed_draw_flags[128];
uniform vec4 observed_open_edges[128];
uniform int observed_cell_count=0;
uniform float observed_emission_gain=0.1;
uniform float observed_alpha_response=1.0;
uniform float observed_source_contrast=0.0;
uniform float observed_base_film=0.0;

uniform float orb_burst_seconds=0.0;
uniform float orb_burst_envelope=0.0;
render_mode blend_mix;

uniform sampler2D noise_texture_1;
uniform float wave_scale = 30.0;

uniform vec4 main_color : source_color;
uniform vec4 edge_color : source_color;
uniform vec4 glow_color : source_color;

uniform float speed = 1.0;

uniform vec2 texture_scale = vec2(1.0,1.0);
uniform float mask_scale = 0.4;

vec2 scale(vec2 uv, float x, float y){
	mat2 scale = mat2(vec2(1.0/x, 0.0), vec2(0.0, 1.0/y));

	uv -= 0.5;
	uv = uv * scale;
	uv += 0.5;
	return uv;
}

float mask(vec2 uv){
	float mask = distance(vec2(0.5), scale(uv, mask_scale, mask_scale));
	mask = clamp(0.0, 1.0, mask);
	return mask;
}

float wave(float mask, float w_scale, float w_speed){
	float wave = mix(.5, 1.0, sin((mask * w_scale * mask_scale) - (orb_burst_seconds * w_speed)*speed)) * 2.0;
	float masked_wave = wave * (1.0 - mask);
	return masked_wave;
}

void vertex(){
	VERTEX.y = wave(mask(UV), wave_scale, 10.0)*.1;

observed_local_xz=VERTEX.xz;
}

void fragment() {
	vec2 warp_noise_uv = (UV*1.5 - vec2(orb_burst_seconds * .1, orb_burst_seconds * .05)) * texture_scale;
	float warp_noise = texture(noise_texture_1, warp_noise_uv).r;
	vec2 noise_uv = (UV + vec2(orb_burst_seconds * .1)) * texture_scale;
	float noise = texture(noise_texture_1, noise_uv).r;

	noise = clamp(0.0,1.0, noise * warp_noise * 1.5);

	float mask = mask(UV);

	float noise_wave = wave(mask, wave_scale, 10.0) * noise;
	noise_wave = smoothstep(0.05,0.2,noise_wave);
	noise_wave += wave(mask, 10.0, 10.0)*.1;

	vec3 wave_color = mix(main_color, edge_color, noise_wave).rgb;
	wave_color = mix(wave_color, glow_color.rgb, pow(1.0-mask, 4.0));

	ALBEDO = wave_color;
	ALPHA = noise_wave;
	EMISSION = ALBEDO * 2.0;

ALPHA*=orb_burst_envelope;

	float observed_noise=texture(observed_perimeter_texture,observed_local_xz*0.43+vec2(orb_burst_seconds*0.008)).r;
	float observed_width=0.09+0.03*observed_noise;
	float observed_inset=0.015+0.14*observed_noise;
	float observed_radius=0.22+0.06*observed_noise;
	float observed_membership=0.0;float partition_owned=0.0;
	for(int i=0;i<128;i++){
		if(i>=observed_cell_count)break;
		vec2 observed_relative=observed_local_xz-observed_cells[i];
		vec2 observed_distance=abs(observed_relative);
		float observed_inside=1.0-step(0.50001,max(observed_distance.x,observed_distance.y));
		vec4 observed_edges=observed_open_edges[i];
		float observed_edge_x=observed_relative.x<0.0?observed_edges.x:observed_edges.y;
		float observed_edge_z=observed_relative.y<0.0?observed_edges.z:observed_edges.w;
		float observed_soft_x=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.x),observed_edge_x);
		float observed_soft_z=mix(1.0,smoothstep(observed_inset,observed_inset+observed_width,0.5-observed_distance.y),observed_edge_z);
		vec2 observed_corner=max(observed_distance-vec2(0.5-observed_radius),vec2(0.0));
		float observed_round=1.0-smoothstep(observed_radius-observed_width*0.45,observed_radius,length(observed_corner));
		observed_round=mix(1.0,observed_round,observed_edge_x*observed_edge_z);
		float partition_candidate=observed_inside*observed_soft_x*observed_soft_z*observed_round;
		if(partition_candidate>observed_membership)partition_owned=observed_draw_flags[i];
		observed_membership=max(observed_membership,partition_candidate);
	}
	// Mask response precedes the occurrence envelope so birth/death stay finite.
	ALPHA=max(observed_base_film,pow(clamp(ALPHA/max(orb_burst_envelope,0.0001),0.0,1.0),observed_alpha_response))*orb_burst_envelope*observed_membership*partition_owned;
	float observed_native_pattern=texture(observed_perimeter_texture,observed_local_xz*0.8+vec2(orb_burst_seconds*0.008)).r;
	float observed_material_weight=mix(1.0,0.35+0.65*observed_native_pattern*observed_native_pattern,observed_source_contrast);
	ALBEDO*=observed_material_weight;
	ALPHA*=mix(1.0,0.5+0.5*observed_native_pattern,observed_source_contrast);
	EMISSION*=observed_emission_gain;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

