shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float cold_age=0.;
const float opacity=1.00000000000000000;
const bool stream=true;
uniform sampler2D edge_noise:repeat_enable,filter_linear;

render_mode blend_mix,unshaded,cull_disabled,depth_draw_never;

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
const vec2 mask1_scroll=vec2(-0.72000002861022949,0.03500000014901161);
const vec2 mask1_scale=vec2(6.00000000000000000,2.20000004768371580);
const bool mask1_radial=false;
const float mask1_rotation=0.00000000000000000;
const bool use_mask2=true;
uniform sampler2D mask2_texture;
const vec2 mask2_scroll=vec2(-0.34000000357627869,-0.14000000059604645);
const vec2 mask2_scale=vec2(4.00000000000000000,2.59999990463256840);
const float mask2_strength=1.00000000000000000;
const int mask2_blend_mode=3;
const bool mask2_radial=false;
const float mask2_rotation=0.00000000000000000;
const bool use_mask3=false;
uniform sampler2D mask3_texture;
const vec2 mask3_scroll=vec2(0.00000000000000000,0.00000000000000000);
const vec2 mask3_scale=vec2(1.00000000000000000,1.00000000000000000);
const float mask3_strength=1.00000000000000000;
const int mask3_blend_mode=2;
const bool mask3_radial=false;
const float mask3_rotation=0.00000000000000000;

group_uniforms Color;
const vec4 primary_color=vec4(0.38005632162094116,0.69207108020782471,0.78741222620010376,1.00000000000000000);
const vec4 secondary_color=vec4(0.05087607726454735,0.23302197456359863,0.40644833445549011,1.00000000000000000);
const vec4 tertiary_color=vec4(0.01341174636036158,0.06838484108448029,0.13286831974983215,1.00000000000000000);
const bool use_tertiary=false;
const float color_smoothness=0.50000000000000000;

group_uniforms Geometry;
const bool billboard=false;
const float displacement_scale=0.00000000000000000;
const float displacement_offset=0.50000000000000000;

group_uniforms UV;
const float time_scale=1.00000000000000000;
const vec2 texture_scale=vec2(1.00000000000000000,1.00000000000000000);
const int uv_alignment=0;

group_uniforms Emission;
const float emission_strength=0.10000000000000001;

group_uniforms ProximityFade;
const bool proximity_fade=false;
const float proximity_fade_distance=1.00000000000000000;

group_uniforms Transparency;
const vec4 edge_cutoff=vec4(0.00000000000000000,0.00000000000000000,0.00000000000000000,0.00000000000000000);
const float alpha_smoothness=1.00000000000000000;
const float alpha_multiplier=0.94999999999999996;
const int alpha_mode=0;
const float alpha_cutoff=0.00000000000000000;
const float dither_cutoff=0.80000000000000004;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

float mask(vec2 uv, float offset){
	float scaled_time = cold_age * time_scale;
	vec2 m1_mapped_uv = mask1_radial ? uv_radial(uv) * mask1_scale + vec2(offset) : uv * mask1_scale + vec2(offset);
	vec2 m1_uv = uv_rotate(uv_align(m1_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask1_scroll), cold_age * mask1_rotation);
	float m1 = mask1_radial ? textureLod(mask1_texture, m1_uv, 0.0).r : texture(mask1_texture, m1_uv).r;
	float m = m1;
	if(use_mask2){
		vec2 m2_mapped_uv = mask2_radial ? uv_radial(uv) * mask2_scale : uv * mask2_scale;
		vec2 m2_uv = uv_rotate(uv_align(m2_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask2_scroll), cold_age * mask2_rotation);
		float m2 = mask2_radial ? textureLod(mask2_texture, m2_uv, 0.0).r : texture(mask2_texture, m2_uv).r;
		m = mix(m, blendf(m, m2, mask2_blend_mode), mask2_strength);
	}
	if(use_mask3){
		vec2 m3_mapped_uv = mask3_radial ? uv_radial(uv) * mask3_scale : uv * mask3_scale;
		vec2 m3_uv = uv_rotate(uv_align(m3_mapped_uv, uv_alignment) + (vec2(scaled_time) * mask3_scroll), cold_age * mask3_rotation);
		float m3 = mask3_radial ? textureLod(mask3_texture, m3_uv, 0.0).r : texture(mask3_texture, m3_uv).r;
		m = mix(m, blendf(m, m3, mask3_blend_mode), mask3_strength);
	}
	return m;
}

void vertex(){
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
}

void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;vec3 realp=wp/vec3(1.,.81649658,1.);float depth=wp.x+wp.z;float cold_partition=smoothstep(4.260000000000,4.740000000000,depth)*(1.-smoothstep(8.760000000000,9.240000000000,depth));
	float mask_value = mask(UV, COLOR.r);

	float color_mask = smoothstep(0.5 - (color_smoothness * .5), 0.5 + (color_smoothness * .5), mask_value);
	if(use_tertiary) {
		ALBEDO = mix(tertiary_color, secondary_color, pow(color_mask, 3.0)).rgb;
	} else {
		ALBEDO = mix(secondary_color, primary_color, pow(color_mask, 3.0)).rgb;
	}

	EMISSION = ALBEDO * emission_strength;

	float alpha_mask = clamp(0.5 - (alpha_smoothness * .5), 0.5 + (alpha_smoothness * .5), mask_value);
	float alpha = clamp((pow(alpha_mask, 1.8) * alpha_multiplier) * (COLOR.a), 0.0, 1.0);
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

ALPHA*=opacity;
float r=length(realp.xz);float angular=abs(atan(realp.z,max(realp.x,.001)));
	float grain=texture(edge_noise,realp.xz*.21).r;
	ALPHA*=smoothstep(-.03,.18,realp.y)*(1.-smoothstep(11.5+grain*.23,12.,r))*smoothstep(.015+.12*(1.-grain),.18+.34*grain,realp.x*tan(.46251225)-abs(realp.z));
	if(stream){float travel=realp.x/22.;float local_age=cold_age-.10-travel;ALPHA*=pow(abs(dot(NORMAL,VIEW)),.65);ALPHA*=smoothstep(-.08,.06,local_age)*(1.-smoothstep(.58,.98,local_age));}

ALPHA*=cold_partition;

ALPHA *= factory_occurrence_alpha;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}



