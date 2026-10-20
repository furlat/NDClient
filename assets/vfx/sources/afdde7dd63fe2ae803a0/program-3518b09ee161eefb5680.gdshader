shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_cloud_clock=0.0;
uniform float vfx_package_offset_cloud_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

varying flat float cloud_billow_arrival;
uniform float cloud_retirement=0.0;
varying flat float cloud_retire_seed;
uniform float cloud_carrier_feather_uv=0.12;
render_mode blend_mix, unshaded;
uniform float cloud_clock=0.;
uniform float cloud_age=0.;
const float LOOP_PERIOD=5.625;

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


float periodic_rate(float rate){return 6.28318530718*round(rate*LOOP_PERIOD/6.28318530718)/LOOP_PERIOD;}
vec4 loop_texture(sampler2D tex,vec2 uv,vec2 velocity){
 float u=fract((vfx_package_seconds()+vfx_package_offset_cloud_clock)/LOOP_PERIOD+0.5);
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
 float u=fract((vfx_package_seconds()+vfx_package_offset_cloud_clock)/LOOP_PERIOD+0.5);
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
 vec3 wp=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 float tempo=cloud_kind==2?.65:(cloud_kind==3?.35:1.);
 float fold=sin(wp.x*2.1+wp.z*1.6-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*periodic_rate(4.1*tempo));
 vec3 shift=vec3(sin(wp.z*1.9+(vfx_package_seconds()+vfx_package_offset_cloud_clock)*periodic_rate(1.4))*.09,fold*.10,cos(wp.x*1.7-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*periodic_rate(1.2))*.08);
 // Rolling folds propagate toward +world X; the trailing side stretches low.
 if(cloud_kind==4){shift.y+=.18*sin(wp.x*2.5+(vfx_package_seconds()+vfx_package_offset_cloud_clock)*5.)+.12*cos(wp.z*2.-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*4.);}
 shift.y+=roll_weight*(sin(wp.x*2.4-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*7.0)*.27);
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
 cloud_world=(factory_world_to_source * INV_VIEW_MATRIX*MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

cloud_retire_seed=fract(sin(float(INSTANCE_ID)*12.9898+71.3)*43758.5453);

vec3 billow_center=MODEL_MATRIX[3].xyz;
float billow_distance=length(vec3(billow_center.x,max(0.0,billow_center.y)*.60,billow_center.z));
float billow_seed=fract(sin(float(INSTANCE_ID)*18.317+31.7)*43758.5453);
cloud_billow_arrival=.65*billow_distance/cloud_radius+.14*billow_seed;
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
 vec2 flow_uv=cloud_world.xz*.27+vec2((vfx_package_seconds()+vfx_package_offset_cloud_clock)*.025,-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*.035);
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
  float heat=texture(mask2_texture,cloud_world.xz*.43+vec2((vfx_package_seconds()+vfx_package_offset_cloud_clock)*.11,-(vfx_package_seconds()+vfx_package_offset_cloud_clock)*.07)).r;
  float pulse=.5+.5*sin((vfx_package_seconds()+vfx_package_offset_cloud_clock)*5.+cloud_world.y*2.+cloud_world.x);
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
 float spread=smoothstep(cloud_billow_arrival,cloud_billow_arrival+.32,(vfx_package_seconds()+vfx_package_offset_cloud_age)/1.05);
 alpha*=smoothstep(-.06,.18,cloud_world.y)*cloud_opacity*spread;
 // Dense lobes, short readable transitions; no broad transparent gauze.
 alpha=cloud_kind==3?smoothstep(.2,.4,alpha):smoothstep(.04,.72,alpha);
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

vec2 carrier_edge=min(UV,vec2(1.0)-UV);
ALPHA*=smoothstep(0.0,cloud_carrier_feather_uv,carrier_edge.x)*smoothstep(0.0,cloud_carrier_feather_uv,carrier_edge.y);

float retirement_start=cloud_retire_seed*.65;
ALPHA*=1.0-smoothstep(retirement_start,retirement_start+.35,cloud_retirement);
float retirement_remaining=1.0-clamp(cloud_retirement,0.0,1.0);
ALPHA*=retirement_remaining*retirement_remaining*retirement_remaining;

float cloud_macro=loop_texture(mask2_texture,cloud_world.xz*.12+vec2(.17,0.0),vec2(.009,-.007)).r;
ALBEDO*=mix(1.0,mix(.65,1.08,smoothstep(.24,.70,cloud_macro)),0.65);

float fog_density=loop_texture(mask2_texture,cloud_world.xz*.12+vec2(.17,0.0),vec2(.009,-.007)).r;
ALPHA*=mix(.38,1.0,smoothstep(.18,.70,fog_density));

ALPHA *= factory_occurrence_alpha;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}





