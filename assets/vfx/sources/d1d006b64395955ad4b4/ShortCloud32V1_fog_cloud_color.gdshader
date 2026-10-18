shader_type spatial;
render_mode blend_mix, unshaded;
uniform float cloud_clock=0.;
uniform float cloud_age=0.;
const float LOOP_PERIOD=5.625;

#include "res://assets/vfx/sources/e08fb480bf164d265fd0/blend.gdshaderinc"
#include "res://assets/vfx/sources/1dd5110b71ca7da6ba0a/uvtools.gdshaderinc"
#include "res://assets/vfx/sources/41832f2b097466cf1183/alpha.gdshaderinc"

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


float periodic_rate(float rate){return 6.28318530718*round(rate*LOOP_PERIOD/6.28318530718)/LOOP_PERIOD;}
vec4 loop_texture(sampler2D tex,vec2 uv,vec2 velocity){
 float u=fract(cloud_clock/LOOP_PERIOD+0.5);
 float a=u*LOOP_PERIOD-LOOP_PERIOD*0.5;
 float b=fract(u+0.5)*LOOP_PERIOD-LOOP_PERIOD*0.5;
 float weight=pow(sin(3.14159265359*u),2.0);
 return mix(texture(tex,uv+velocity*b),texture(tex,uv+velocity*a),weight);
}
float mask_at(vec2 uv,float offset,float phase_time){
	float scaled_time = phase_time * time_scale;
	vec2 m1_mapped_uv = mask1_radial ? uv_radial(uv) * mask1_scale + vec2(offset) : uv * mask1_scale + vec2(offset);
	vec2 m1_uv = uv_rotate(uv_align(m1_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask1_scroll), phase_time * mask1_rotation);
	float m1 = mask1_radial ? textureLod(mask1_texture, m1_uv, 0.0).r : texture(mask1_texture, m1_uv).r;
	float m = m1;
	if(use_mask2){
		vec2 m2_mapped_uv = mask2_radial ? uv_radial(uv) * mask2_scale : uv * mask2_scale;
		vec2 m2_uv = uv_rotate(uv_align(m2_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask2_scroll), phase_time * mask2_rotation);
		float m2 = mask2_radial ? textureLod(mask2_texture, m2_uv, 0.0).r : texture(mask2_texture, m2_uv).r;
		m = mix(m, blendf(m, m2, mask2_blend_mode), mask2_strength);
	}
	if(use_mask3){
		vec2 m3_mapped_uv = mask3_radial ? uv_radial(uv) * mask3_scale : uv * mask3_scale;
		vec2 m3_uv = uv_rotate(uv_align(m3_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask3_scroll), phase_time * mask3_rotation);
		float m3 = mask3_radial ? textureLod(mask3_texture, m3_uv, 0.0).r : texture(mask3_texture, m3_uv).r;
		m = mix(m, blendf(m, m3, mask3_blend_mode), mask3_strength);
	}
	return m;
}


float mask(vec2 uv,float offset){
 float u=fract(cloud_clock/LOOP_PERIOD+0.5);
 float a=u*LOOP_PERIOD-LOOP_PERIOD*0.5;
 float b=fract(u+0.5)*LOOP_PERIOD-LOOP_PERIOD*0.5;
 return mix(mask_at(uv,offset,b),mask_at(uv,offset,a),pow(sin(3.14159265359*u),2.0));
}

uniform int cloud_kind=0;
uniform bool solid_core=false;
uniform float cloud_radius=4.;
uniform float roll_weight=0.;
uniform float cloud_opacity=1.;
varying vec3 cloud_world;
void vertex(){
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float tempo=cloud_kind==2?.65:(cloud_kind==3?.35:1.);
 float fold=sin(wp.x*2.1+wp.z*1.6-cloud_clock*periodic_rate(4.1*tempo));
 vec3 shift=vec3(sin(wp.z*1.9+cloud_clock*periodic_rate(1.4))*.09,fold*.10,cos(wp.x*1.7-cloud_clock*periodic_rate(1.2))*.08);
 // Rolling folds propagate toward +world X; the trailing side stretches low.
 if(cloud_kind==4){shift.y+=.18*sin(wp.x*2.5+cloud_clock*5.)+.12*cos(wp.z*2.-cloud_clock*4.);}
 shift.y+=roll_weight*(sin(wp.x*2.4-cloud_clock*7.0)*.27);
 shift.x+=roll_weight*(fold*.24-.20*(1.-smoothstep(-3.,2.,wp.x)));
 VERTEX+=inverse(mat3(MODEL_MATRIX))*shift;
 

	float mask_value = mask(UV, COLOR.r) - displacement_offset;
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
 // Sample the actual billboard position, including its camera-facing vertices.
 cloud_world=(INV_VIEW_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.)).xyz;
}

void fragment() {
	float mask_value = mask(UV, COLOR.r);

	float color_mask = smoothstep(0.5 - (color_smoothness * .5), 0.5 + (color_smoothness * .5), mask_value);
	if(use_tertiary) {
		ALBEDO = mix(tertiary_color, secondary_color, pow(color_mask, 3.0)).rgb;
	} else {
		ALBEDO = mix(secondary_color, primary_color, pow(color_mask, 3.0)).rgb;
	}

 // Broad, shared folds give the full cloud structure even where many
 // authored transparent particles overlap. Keep the original moving masks.
 vec2 flow_uv=cloud_world.xz*.27+vec2(cloud_clock*.025,-cloud_clock*.035);
 float broad=(loop_texture(mask2_texture,cloud_world.xz*.27,vec2(.025,-.035)).r
 +loop_texture(mask2_texture,cloud_world.xy*.32+vec2(0.,.24),vec2(.018,0.)).r
 +loop_texture(mask2_texture,cloud_world.zy*.38+vec2(-.18,0.),vec2(0.,.023)).r)/3.;
 float fold_light=smoothstep(.18,.78,broad*.9+mask_value*.1);
 ALBEDO=mix(tertiary_color.rgb,secondary_color.rgb,fold_light);
 ALBEDO=mix(ALBEDO,primary_color.rgb,smoothstep(.5,.9,fold_light)*.85);
 if(cloud_kind==3){
  float dark_noise=loop_texture(mask2_texture,cloud_world.xz*.18,vec2(.008,-.012)).r*.7
   +loop_texture(mask2_texture,cloud_world.xy*.22+vec2(.21,0.),vec2(0.,.014)).r*.3;
  float dark_fold=smoothstep(.2,.8,dark_noise);
  ALBEDO=mix(tertiary_color.rgb,secondary_color.rgb,pow(dark_fold,1.3));
  ALBEDO=mix(ALBEDO,primary_color.rgb,smoothstep(.72,.96,dark_fold)*.8);
 }
 if(cloud_kind==4){
  float heat=texture(mask2_texture,cloud_world.xz*.43+vec2(cloud_clock*.11,-cloud_clock*.07)).r;
  float pulse=.5+.5*sin(cloud_clock*5.+cloud_world.y*2.+cloud_world.x);
  ALBEDO=mix(tertiary_color.rgb,secondary_color.rgb,fold_light);
  ALBEDO=mix(ALBEDO,primary_color.rgb,smoothstep(.63,.88,heat)*(.65+.35*pulse));
 }
 EMISSION = vec3(0.);

	float alpha_mask = clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value);
	float alpha = clamp((pow(alpha_mask, 2.0) * alpha_multiplier) * COLOR.a, 0.0, 1.0);
 // Natural sphere envelope authored in the Godot material, not a tile stencil.
 if(solid_core){alpha=1.;}
 float radial=length(cloud_world.xz);
 alpha*=1.-smoothstep(cloud_radius-.25,cloud_radius,length(vec3(cloud_world.x,max(0.,cloud_world.y),cloud_world.z)));
 // A noisy arrival front lets connected billows proliferate from the center.
 float arrival=radial/cloud_radius + .12*sin(cloud_world.x*2.2+cloud_world.z*1.4)
   + .08*sin(cloud_world.z*3.1-cloud_world.x*.8);
 float spread=smoothstep(arrival,arrival+.16,cloud_age/1.05);
 alpha*=smoothstep(-.06,.18,cloud_world.y)*cloud_opacity*spread;
 // Dense lobes, short readable transitions; no broad transparent gauze.
 alpha=cloud_kind==3?smoothstep(.2,.4,alpha):smoothstep(.12,.62,alpha);
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
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
