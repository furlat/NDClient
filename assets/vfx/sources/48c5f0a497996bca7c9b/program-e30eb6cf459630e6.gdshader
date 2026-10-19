shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
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
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_noise : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float side = 0.0;
varying vec3 wp;
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
wp=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float dep=wp.x+wp.z;
 if((side<-.5 && dep>=0.) || (side>.5 && dep<0.)) discard;
 float n=texture(source_noise,UV*vec2(5.,.8)+vec2(-(vfx_package_seconds()+vfx_package_offset_clock)*.48,seed)).r;
 float stria=.5+.5*sin(UV.x*75.398-(vfx_package_seconds()+vfx_package_offset_clock)*12.+n*4.+seed*6.);
 float edge=pow(max(0.,1.-abs(UV.y-.5)*2.),1.4);
 float taper=smoothstep(0.,.055,UV.x)*(1.-smoothstep(.91,1.,UV.x));
 float core=pow(stria,2.);
 ALBEDO=vec3(.19+.55*core+.15*n);
 ALPHA=edge*taper*strength*(.45+.55*n)*(.5+.5*stria);

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
	}


