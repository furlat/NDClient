shader_type spatial;
varying vec2 observed_local_xz;
uniform sampler2D observed_perimeter_texture;
uniform vec2 observed_cells[32];
uniform vec4 observed_open_edges[32];
uniform int observed_cell_count=0;
uniform float observed_emission_gain=0.1;
uniform float observed_alpha_response=1.0;
uniform float observed_source_contrast=0.0;
uniform float observed_base_film=0.0;

uniform float orb_burst_seconds=0.0;
uniform float orb_burst_envelope=0.0;
render_mode blend_mix;

float blendf(float a, float b, int mode){
	float result = 0.0;
	if(mode == 0) {result = a + b;} // Add
	if(mode == 1) {result = a - b;} // Sub
	if(mode == 2) {result = a * b;} // Mult
	if(mode == 3) {result = min(a, b);} // Darken
	if(mode == 4) {result = max(a, b);} // Lighten
	if(mode == 5) {result = 1.0 - (1.0 - a) * (1.0 - b);} // Screen
	if(mode == 6) {result =  a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));} // Overlay
	if(mode == 7) {result = b < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));} // Hard Light
	if(mode == 8) {result = b < 0.5 ? (2.0 * a * b + a * a * (1.0 - 2.0 * b)) : (sqrt(a) * (2.0 * b - 1.0) + (2.0 * a) * (1.0 - b));} // Soft Light
	if(mode == 9) {result = a / (1.0 - b);} // Color Dodge
	if(mode == 10) {result = 1.0 - (1.0 - a) / b;} // Burn
	if(mode == 11) {result = a + b - 1.0;} // Burn
	return result;
}

vec2 uv_align(vec2 uv, int align_mode) {
	switch(align_mode){
		case 0: return vec2(uv.x, uv.y);
		case 1: return vec2(uv.y, uv.x);
		case 2: return vec2(1.0 - uv.x, uv.y);
		case 3: return vec2(1.0 - uv.y, uv.x);
	}
	return vec2(uv.x, uv.y);
}

vec2 uv_radial(vec2 uv){
	vec2 centered_uv = uv - vec2(0.5);
	float r = sqrt(pow(centered_uv.x,2.0)+pow(centered_uv.y,2.0));
	float theta = atan(centered_uv.x, centered_uv.y) / (2.0 * PI);
	return vec2(theta, r);
}

vec2 uv_rotate(vec2 uv, float angle)
{
	vec2 pivot = vec2(0.5,0.5);
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));

	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}


float bayer4x4(vec4 frag){
	ivec2 pixel = ivec2(frag.xy);
	int x = pixel.x & 3;
	int y = pixel.y & 3;
	int i = x + y * 4;
	float m[16] = float[](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);
	return (m[i] + 0.5) / 32.0;
}


const vec3 ign = vec3(0.06711056f, 0.00583715f, 52.9829189f);

bool alpha_discard(float value, vec4 frag, int mode, float d_cutoff, float a_cutoff){
	if(mode == 0){
		return false;
	} else if (mode == 1) {
		if(value < a_cutoff){
			return true;
		} else if (value < d_cutoff || value < fract(ign.z * fract(dot(frag.xy, ign.xy)))) {
			return true;
		}
	} else if (mode == 2) {
		if (value < a_cutoff){
			return true;
		}
	} else if (mode == 3) {
		if(value < a_cutoff){
			return true;
		} else if (value < d_cutoff){
			float rest = smoothstep(0.02, 0.5, value);
			if (rest < bayer4x4(frag)){
				return true;
			}
		}
	}
	return false;
}


group_uniforms Masks;
uniform sampler2D mask1_texture;
uniform vec2 mask1_scroll = vec2(0.0);
uniform vec2 mask1_scale = vec2(1.0);
uniform bool mask1_radial = false;
uniform float mask1_rotation = 0.0;
uniform bool use_mask2 = false;
uniform sampler2D mask2_texture;
uniform vec2 mask2_scroll = vec2(0.0);
uniform vec2 mask2_scale = vec2(1.0);
uniform float mask2_strength : hint_range(0.0, 1.0, 0.01);
uniform int mask2_blend_mode : hint_range(0, 11, 1) = 0;
uniform bool mask2_radial = false;
uniform float mask2_rotation = 0.0;
uniform bool use_mask3 = false;
uniform sampler2D mask3_texture;
uniform vec2 mask3_scroll = vec2(0.0);
uniform vec2 mask3_scale = vec2(1.0);
uniform float mask3_strength : hint_range(0.0, 1.0, 0.01);
uniform int mask3_blend_mode : hint_range(0, 11, 1) = 0;
uniform bool mask3_radial = false;
uniform float mask3_rotation = 0.0;

group_uniforms Color;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform vec4 tertiary_color : source_color;
uniform bool use_tertiary = false;
uniform float color_smoothness : hint_range(0.0, 1.0, 0.1) = 0.5;

group_uniforms Geometry;
uniform bool billboard = false;
uniform float displacement_scale : hint_range(0.0, 1.0, 0.05) = 0.0;
uniform float displacement_offset : hint_range(0.0, 1.0, 0.05) = 0.5;

group_uniforms UV;
uniform float time_scale = 1.0;
uniform vec2 texture_scale = vec2(1.0);
uniform int uv_alignment : hint_range(0, 3, 1);

group_uniforms Emission;
uniform float emission_strength = 2.0;

group_uniforms ProximityFade;
uniform bool proximity_fade = false;
uniform float proximity_fade_distance : hint_range(0.0, 4096.0, 0.01) = 1.0;

group_uniforms Transparency;
uniform vec4 edge_cutoff = vec4(0.0);
uniform float alpha_smoothness : hint_range(0.0, 1.0, 0.05) = 0.954;
uniform float alpha_multiplier : hint_range(0.0, 1.0, 0.05) = 0.954;
uniform int alpha_mode : hint_range(0, 3, 1) = 0;
uniform float alpha_cutoff : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float dither_cutoff : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

float mask(vec2 uv){
	float scaled_time = orb_burst_seconds * time_scale;
	vec2 m1_mapped_uv = mask1_radial ? uv_radial(uv) * mask1_scale : uv * mask1_scale;
	vec2 m1_uv = uv_rotate(uv_align(m1_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask1_scroll), orb_burst_seconds * mask1_rotation);
	float m1 = mask1_radial ? textureLod(mask1_texture, m1_uv, 0.0).r : texture(mask1_texture, m1_uv).r;
	float m = m1;
	if(use_mask2){
		vec2 m2_mapped_uv = mask2_radial ? uv_radial(uv) * mask2_scale : uv * mask2_scale;
		vec2 m2_uv = uv_rotate(uv_align(m2_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask2_scroll), orb_burst_seconds * mask2_rotation);
		float m2 = mask2_radial ? textureLod(mask2_texture, m2_uv, 0.0).r : texture(mask2_texture, m2_uv).r;
		m = mix(m, blendf(m, m2, mask2_blend_mode), mask2_strength);
	}
	if(use_mask3){
		vec2 m3_mapped_uv = mask3_radial ? uv_radial(uv) * mask3_scale : uv * mask3_scale;
		vec2 m3_uv = uv_rotate(uv_align(m3_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask3_scroll), orb_burst_seconds * mask3_rotation);
		float m3 = mask3_radial ? textureLod(mask3_texture, m3_uv, 0.0).r : texture(mask3_texture, m3_uv).r;
		m = mix(m, blendf(m, m3, mask3_blend_mode), mask3_strength);
	}
	return m;
}

void vertex(){
	float mask_value = mask(UV) - displacement_offset;
	VERTEX += NORMAL * mask_value * displacement_scale;

	if(billboard){
		// Billboard Mode: Enabled
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
				MAIN_CAM_INV_VIEW_MATRIX[0],
				MAIN_CAM_INV_VIEW_MATRIX[1],
				MAIN_CAM_INV_VIEW_MATRIX[2],
				MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}

observed_local_xz=VERTEX.xz;
}

void fragment() {
	float mask_value = mask(UV);

	float color_mask = smoothstep(0.5 - (color_smoothness * .5), 0.5 + (color_smoothness * .5), mask_value);
	if(use_tertiary) {
		ALBEDO = mix(tertiary_color, secondary_color, pow(color_mask, 3.0)).rgb;
	} else {
		ALBEDO = mix(secondary_color, primary_color, pow(color_mask, 3.0)).rgb;
	}

	EMISSION = ALBEDO * emission_strength;

	float alpha_mask = clamp(mask_value, 0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5));
	float alpha = clamp((pow(alpha_mask, 3.0) * alpha_multiplier) * (COLOR.a), 0.0, 1.0);
	if(edge_cutoff != vec4(0.0)){
		if(UV.x < edge_cutoff.x){ discard; }
		if(UV.y < edge_cutoff.y){ discard; }
		if(UV.x > 1.0-edge_cutoff.z){ discard; }
		if(UV.y > 1.0-edge_cutoff.w){ discard; }
	}

	// Proximity Fade: Enabled
	if(proximity_fade){
		float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
		proximity_view_pos.xyz /= proximity_view_pos.w;
		alpha *= clamp(1.0 - smoothstep(proximity_view_pos.z + proximity_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	}

	if(alpha_mode == 0){
		ALPHA = alpha;
	} else {
		if(alpha_discard(alpha, FRAGCOORD, alpha_mode, dither_cutoff, alpha_cutoff)){
			discard;
		}
	}

ALPHA*=orb_burst_envelope;

	float observed_noise=texture(observed_perimeter_texture,observed_local_xz*0.43+vec2(orb_burst_seconds*0.008)).r;
	float observed_width=0.09+0.03*observed_noise;
	float observed_inset=0.015+0.14*observed_noise;
	float observed_radius=0.22+0.06*observed_noise;
	float observed_membership=0.0;
	for(int i=0;i<32;i++){
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
		observed_membership=max(observed_membership,observed_inside*observed_soft_x*observed_soft_z*observed_round);
	}
	// Mask response precedes the occurrence envelope so birth/death stay finite.
	ALPHA=max(observed_base_film,pow(clamp(ALPHA/max(orb_burst_envelope,0.0001),0.0,1.0),observed_alpha_response))*orb_burst_envelope*observed_membership;
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

