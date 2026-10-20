shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_age=0.0;
uniform float vfx_package_offset_gpu_summon_time=0.0;

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


uniform sampler2D neutral_family:filter_nearest,repeat_disable;
uniform float neutral_levels[64];
uniform int neutral_count=8;
uniform float neutral_gain=1.45;
uniform bool neutral_albedo_is_encoded=false;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float age=0.0;
uniform float strength=0.0;
uniform float seed=0.0;
uniform float side=0.0;
uniform vec2 camera_ground=vec2(.70710678,.70710678);
varying vec3 world_p;
uniform int gpu_summon_piece = 0;
uniform int gpu_summon_kind = 0;
uniform float gpu_summon_time = 0.0;
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	float u=point.x/28.0;
	float edge=point.y;
	bool cast=gpu_summon_kind==3;
	int lanes=cast?2:3;
	int quarter=gpu_summon_piece/lanes;
	float lane=float(gpu_summon_piece%lanes);
	float base=float(quarter)*3.14159265359/2.0+lane*.31;
	float contract=gpu_summon_kind==1?1.0-smoothstep(.28,1.24,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time))*.77:.58+.42*smoothstep(0.0,.46,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time));
	float radius=.58+lane*.135;
	if(cast){radius=.15+lane*.04;contract=1.0;}
	float rotation=(vfx_package_seconds()+vfx_package_offset_gpu_summon_time)*(gpu_summon_kind!=1?.95:-1.15);
	float span=1.08+lane*.12;
	if(gpu_summon_kind==2){radius*=1.0+smoothstep(.12,.60,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time))*.25;span*=1.0-smoothstep(.17,.63,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time))*.7;}
	float theta=base+rotation+u*span;
	radius*=contract*(1.0+.07*sin(u*5.0+lane));
	float height=.05+(lane*.18+u*.55)*smoothstep(.05,.52,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time));
	if(gpu_summon_kind==1)height=.13+(.30+u*.76)*(1.0-smoothstep(.62,1.34,(vfx_package_seconds()+vfx_package_offset_gpu_summon_time)));
	if(cast)height=(u-.5)*.27;
	if(gpu_summon_kind==2)height=.4+u*.30;
	float width=(.07+lane*.023)*pow(max(0.0,sin(u*3.14159265359)),.55);
	if(cast)width*=.70;
	point=vec3(cos(theta)*radius,height+edge*width,sin(theta)*radius);
	normal=vec3(0.0,0.0,1.0);
	tangent=vec3(1.0,0.0,0.0);
	binormal=vec3(0.0,1.0,0.0);
}

void vertex(){gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);world_p=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float depth=dot(world_p.xz,camera_ground);
 if(side<-.5 && depth>=0.)discard;
 if(side>.5 && depth<0.)discard;
 float n=texture(noise_tex,vec2(UV.x*2.-(vfx_package_seconds()+vfx_package_offset_age)*.5+seed,UV.y*.65+seed)).r;
 float edge=sin(clamp(UV.y,0.,1.)*3.14159265);
 float taper=pow(sin(clamp(UV.x,0.,1.)*3.14159265),.72);
 float grain=smoothstep(.18,.73,n);
 float core=pow(edge,3.)*(.45+.55*grain)*taper;
 ALBEDO=vec3(.40+.60*core);
 ALPHA=smoothstep(.04,.35,core)*strength*(.50+.47*grain);

	float neutral_encoded = (cie_encoded_channel(ALBEDO.r) + cie_encoded_channel(ALBEDO.g) + cie_encoded_channel(ALBEDO.b)) / 3.0;
	if (neutral_albedo_is_encoded) neutral_encoded = (ALBEDO.r+ALBEDO.g+ALBEDO.b)/3.0;
	neutral_encoded = min(neutral_encoded * neutral_gain, neutral_levels[neutral_count-1]);
	int neutral_choice = 0;
	float neutral_distance = 1000.0;
	for (int index=0; index<64; index++) {
		if (index>=neutral_count) break;
		float candidate_distance = abs(neutral_encoded-neutral_levels[index]);
		if (candidate_distance<neutral_distance) {
			neutral_choice=index;
			neutral_distance=candidate_distance;
		}
	}
	vec3 family_encoded = texture(neutral_family,vec2((float(neutral_choice)+0.5)/float(neutral_count),0.5)).rgb;
	ALBEDO=vec3(cie_linear_channel(family_encoded.r),cie_linear_channel(family_encoded.g),cie_linear_channel(family_encoded.b));
	}



