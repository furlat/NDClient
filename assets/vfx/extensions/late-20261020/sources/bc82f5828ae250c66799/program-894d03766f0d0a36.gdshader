shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
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
uniform float strength=0.0;
uniform float side=0.0;
uniform vec2 camera_ground=vec2(.70710678,.70710678);
varying vec3 world_p;
uniform float gpu_summon_time = 0.0;
uniform int gpu_summon_kind = 0;
uniform int gpu_summon_camera_quadrant = 0;
varying flat float gpu_mote_strength;

float gpu_source_envelope(float age) {
	if(gpu_summon_kind==0)return smoothstep(0.0,.30,age)*(1.0-smoothstep(.90,1.64,age));
	if(gpu_summon_kind==1)return smoothstep(0.0,.22,age)*(1.0-smoothstep(.92,1.42,age));
	if(gpu_summon_kind==2)return smoothstep(0.0,.10,age)*(1.0-smoothstep(.30,.68,age));
	return smoothstep(0.0,.10,age)*(1.0-smoothstep(.27,.70,age));
}

void gpu_mote_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,int mote_index,out float amount){
	bool cast=gpu_summon_kind==3;
	int sector=mote_index/(cast?4:8);
	int seed=mote_index%(cast?4:8);
	float offset=float(seed);
	float age=(vfx_package_seconds()+vfx_package_offset_gpu_summon_time);
	float life=clamp((age-offset*.037)/1.1,0.0,1.0);
	float theta=float(sector)*3.14159265359/2.0+offset*.18+age*.9;
	float radius=(.40+offset*.065)*(1.0+life*.28);
	float height=.03+life*(.72+offset*.08);
	if(gpu_summon_kind==1){radius*=1.0-smoothstep(.24,1.3,age)*.8;height=.13+(1.0-life)*(.4+offset*.09);}
	if(cast){radius=.10+life*.20;height=(offset-1.5)*.055+sin(life*3.14159265359)*.15;}
	if(gpu_summon_kind==2){radius*=1.0+life*.45;height=.35+life*.45;}
	vec3 origin=vec3(cos(theta)*radius,height,sin(theta)*radius);
	float size=.35+float(seed%3)*.18;
	float yaw=3.14159265359/4.0-float(gpu_summon_camera_quadrant)*3.14159265359/2.0;
	float cy=cos(yaw),sy=sin(yaw),cx=cos(-3.14159265359/6.0),sx=sin(-3.14159265359/6.0);
	mat3 rotation=mat3(vec3(cy,0.0,-sy),vec3(sy*sx,cx,cy*sx),vec3(sy*cx,-sx,cy*cx));
	point=origin+rotation*point*size;
	normal=rotation*normal;
	tangent=rotation*tangent;
	binormal=rotation*binormal;
	amount=gpu_source_envelope(age)*(.55+float(seed%3)*.12);
}

void vertex(){float instance_strength;gpu_mote_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,INSTANCE_ID,instance_strength);gpu_mote_strength=instance_strength;world_p=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float d=dot(world_p.xz,camera_ground);
 if(side<-.5&&d>=0.)discard;if(side>.5&&d<0.)discard;
 vec2 p=(UV-.5)*2.;float r=length(p);float halo=1.-smoothstep(.18,1.,r);float core=1.-smoothstep(.05,.28,r);
 ALBEDO=vec3(.22+.68*core+.08*halo);
 ALPHA=(core*.72+halo*.26)*strength;

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
	
ALPHA*=gpu_mote_strength;
}



