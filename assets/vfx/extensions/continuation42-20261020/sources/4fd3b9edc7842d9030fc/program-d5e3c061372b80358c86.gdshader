shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;


uniform vec3 recovery_color_low;
uniform vec3 recovery_color_mid;
uniform vec3 recovery_color_high;
uniform float recovery_levels[8];
uniform float recovery_maximum_byte;
vec3 recovery_decode_srgb(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), encoded));
}

render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, unshaded;
uniform sampler2D flow_tex : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float strength = 1.0;
uniform float broad = 0.0;
uniform float side = 0.0;
uniform vec2 camera_ground = vec2(1.0,1.0);
varying vec3 world_p;
// Geometry-only port of the existing authored class/recovery strip equations.
// The donor fragment, palette, opacity, texture and all live owner gates stay.
uniform int factory_motion_kind = 0;
uniform int factory_piece_index = 0;

vec3 factory_unit(vec3 value) {
	float magnitude = length(value);
	return magnitude > 0.0000001 ? value / magnitude : vec3(0.0);
}

vec3 factory_rotate_y(vec3 point, float angle) {
	return vec3(cos(angle)*point.x+sin(angle)*point.z, point.y, -sin(angle)*point.x+cos(angle)*point.z);
}

vec3 factory_strip_point(float u) {
	float index = float(factory_piece_index);
	float phase = 3.141592653589793 * (vfx_package_seconds()+vfx_package_offset_clock);
	float angle;
	float radius;
	if (factory_motion_kind == 0) {
		angle=u*6.28318530718*.67+index*1.26+phase;
		radius=.29+.09*sin(u*3.14159265359+index);
		return vec3(cos(angle)*radius,.16+u*(.85+.16*sin(index))+.035*sin(phase+index),sin(angle)*radius);
	}
	if (factory_motion_kind == 1 || factory_motion_kind == 10) {
		angle=index*.9+u*1.6+.12*sin(phase+index);
		radius=.25+u*.60;
		return vec3(cos(angle)*radius,.025+.02*sin(u*3.14159265359),sin(angle)*radius);
	}
	if (factory_motion_kind == 2 || factory_motion_kind == 11) {
		angle=index*1.047+.25*sin(phase+u*2.0);
		radius=.22+.07*sin(u*3.14159265359);
		return vec3(cos(angle)*radius,u*1.32,sin(angle)*radius);
	}
	if (factory_motion_kind == 3) {
		angle=index*6.28318530718/6.0;
		float reach=.05+clamp((vfx_package_seconds()+vfx_package_offset_clock)/.45,0.0,1.0)*.65;
		return vec3(cos(angle)*reach*u,.40+.18*sin(u*3.14159265359)+(vfx_package_seconds()+vfx_package_offset_clock)*.18,sin(angle)*reach*u);
	}
	if (factory_motion_kind == 8) {
		angle=index*6.28318530718/5.0+u*.80+.14*sin(phase+index);
		radius=.40+.025*sin(3.14159265359*u);
		return vec3(cos(angle)*radius,.20+float(factory_piece_index%3)*.12+.42*sin(u*3.14159265359*.5),sin(angle)*radius);
	}
	if (factory_motion_kind == 9) {
		angle=index*2.399963+u*.38+.08*sin(phase+u*3.14159265359+index);
		radius=.25+.045*sin(u*3.14159265359)+.025*cos(phase+index);
		return vec3(cos(angle)*radius,.10+float(factory_piece_index%3)*.15+u*.63,sin(angle)*radius);
	}
	angle=u*6.28318530718*.86+(vfx_package_seconds()+vfx_package_offset_clock)*6.28318530718*(factory_motion_kind==4?2.0:.65)+index*1.57;
	if (factory_motion_kind == 4) {
		radius=.21+.12*u;
		return factory_rotate_y(vec3(cos(angle)*radius,sin(angle)*radius,0.0),index*6.28318530718/3.0);
	}
	if (factory_motion_kind == 5) {
		return factory_rotate_y(vec3(cos(angle)*.20,sin(angle)*.20,0.0),factory_piece_index%2==0?.75:-.75)+vec3(factory_piece_index<2?-.20:.20,0.0,0.0);
	}
	if (factory_motion_kind == 6) {
		radius=.14+index*.095+smoothstep(0.0,.8,(vfx_package_seconds()+vfx_package_offset_clock))*.10;
		float rotation=.5+index*.30;
		return vec3(cos(angle)*radius,-sin(rotation)*sin(angle)*radius,cos(rotation)*sin(angle)*radius);
	}
	angle=u*6.28318530718*.80+index*1.256+(vfx_package_seconds()+vfx_package_offset_clock)*6.28318530718*.25;
	radius=.36+.035*sin(u*3.14159265359);
	return vec3(cos(angle)*radius,.10+u*1.12,sin(angle)*radius);
}

vec3 factory_strip_vertex(vec2 source_uv) {
	float u=source_uv.x;
	vec3 point=factory_strip_point(u);
	if (factory_motion_kind == 11) {
		float angle=float(factory_piece_index)*1.047;
		return point+vec3(cos(angle),0.0,sin(angle))*.065*(source_uv.y*2.0-1.0);
	}
	vec3 tangent;
	vec3 across;
	float width;
	if (factory_motion_kind == 9) {
		tangent=factory_unit(factory_strip_point(min(1.0,u+.005))-factory_strip_point(max(0.0,u-.005)));
		vec3 radial=factory_unit(vec3(point.x,0.0,point.z));
		across=factory_unit(cross(tangent,radial));
		width=.035*pow(max(0.0,sin(3.14159265359*u)),.6);
		return source_uv.y==.5?point+radial*.014*sin(3.14159265359*u):point+across*width*(source_uv.y*2.0-1.0);
	}
	if (factory_motion_kind == 10) {
		tangent=factory_unit(factory_strip_point(min(1.0,u+.01))-point);
		across=factory_unit(cross(tangent,vec3(0.0,1.0,0.0)));
		width=.065;
	} else {
		tangent=factory_unit(factory_strip_point(min(1.0,u+.005))-factory_strip_point(max(0.0,u-.005)));
		across=factory_unit(cross(tangent,vec3(.5,.7,.5)));
		width=factory_motion_kind==7 || factory_motion_kind==8?.045:(factory_motion_kind>=4 && factory_motion_kind<=6?.026:(factory_motion_kind==0?.05:.065));
	}
	if (length(across)<.1) across=vec3(1.0,0.0,0.0);
	return point+across*width*(source_uv.y*2.0-1.0);
}

void vertex(){
VERTEX = factory_strip_vertex(UV);
 world_p = (factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float dep = dot(world_p.xz,camera_ground);
 if ((side < -0.5 && dep >= 0.0) || (side > 0.5 && dep < 0.0)) discard;
 float phase = (vfx_package_seconds()+vfx_package_offset_clock) * 3.14159265359;
 vec2 motion = vec2(cos(phase),sin(phase))*.18;
 float n = texture(flow_tex, UV*vec2(2.8,.8)+motion+seed).r;
 float st = .5 + .5*sin(UV.x*25.132741 - phase*2.0+seed*10.0);
 float center = pow(max(0.0,1.0-abs(UV.y-.5)*2.0),mix(2.0,1.0,broad));
 float ends = smoothstep(0.0,.16,UV.x)*(1.0-smoothstep(.72,1.0,UV.x));
 float a = center*ends*(.32+.68*st)*(.6+.4*n)*strength;
 float v = .26+.57*st+.12*n;
 ALBEDO = vec3(v); ALPHA = a*mix(.8,.45,broad);

	// Raw source shader scalar is the Compatibility-encoded value. Do not apply
	// generic Reinhard/CIE finishing or Forward+ encode it before extraction.
	float recovery_byte = clamp(ALBEDO.r, 0.0, 1.0) * 255.0;
	float recovery_neutral = recovery_levels[0];
	float recovery_distance = abs(recovery_byte - recovery_neutral);
	for (int recovery_index = 1; recovery_index < 8; recovery_index++) {
		float candidate_distance = abs(recovery_byte - recovery_levels[recovery_index]);
		if (candidate_distance < recovery_distance) {
			recovery_distance = candidate_distance;
			recovery_neutral = recovery_levels[recovery_index];
		}
	}
	float recovery_position = clamp(recovery_neutral / recovery_maximum_byte, 0.0, 1.0) * 2.0;
	vec3 recovery_encoded = recovery_position < 1.0
		? mix(recovery_color_low, recovery_color_mid, recovery_position)
		: mix(recovery_color_mid, recovery_color_high, recovery_position - 1.0);
	recovery_encoded = floor(recovery_encoded * 255.0 + vec3(0.5)) / 255.0;
	ALBEDO = recovery_decode_srgb(recovery_encoded);

ALPHA *= factory_occurrence_alpha;
}


