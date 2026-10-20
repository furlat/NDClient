shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

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
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_opacity=1.0;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D source_noise:repeat_enable,filter_linear;
uniform sampler2D source_wave:repeat_enable,filter_linear;
uniform int style=0;
void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


 if(style==2){
  vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);
  float edge=abs(r-(.65+.08*cos(a*6.)));
  float border=(1.-smoothstep(.035,.085,edge))*step(.18,fract(a*1.909859+(vfx_package_seconds()+vfx_package_offset_support_clock)*.04));
  float slash=min(abs(p.x*.72+p.y),abs(p.x*.72-p.y));
  float runes=(1.-smoothstep(.025,.070,slash))*smoothstep(.18,.30,r)*(1.-smoothstep(.55,.70,r));
  float n0=texture(source_noise,UV*3.+vec2(0.,-(vfx_package_seconds()+vfx_package_offset_support_clock)*.5)).r;
  float coverage=max(border,runes)*smoothstep(.18,.32,n0);
  float env=smoothstep(0.,.045,(vfx_package_seconds()+vfx_package_offset_support_clock))*(1.-smoothstep(.24,.50,(vfx_package_seconds()+vfx_package_offset_support_clock)));
  ALBEDO=mix(vec3(.56,.035,.04),vec3(1.,.30,.21),n0);
  EMISSION=ALBEDO*(.7+1.5*n0);ALPHA=coverage*env;
 } else {
 float n=texture(source_noise,UV*vec2(4.,2.2)+vec2(.05,-.12)*(vfx_package_seconds()+vfx_package_offset_support_clock)).r;
 float detail=texture(source_noise,UV*vec2(10.,7.)+vec2(-.07,.04)*(vfx_package_seconds()+vfx_package_offset_support_clock)).r;
 float wave=texture(source_wave,UV*vec2(2.,1.)+vec2(.03,-.18)*(vfx_package_seconds()+vfx_package_offset_support_clock)).r;
 float threshold=.34+.36*smoothstep(.50,1.30,(vfx_package_seconds()+vfx_package_offset_support_clock));
 float patch=smoothstep(threshold,threshold+.045,n)*smoothstep(.015,.13,wave);
 float sector=.5+.5*sin(UV.x*18.8495559+sin(UV.y*8.));
 patch*=smoothstep(.2,.5,sector);
 float rim=1.-smoothstep(.03,.075,abs(n-threshold));
 float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 float light=.12+.11*wave+.47*rim*patch;
 float alpha=patch*(.55+.36*detail);
 if(style==1){light=.16+.30*detail;alpha=.80;}
 ALBEDO=vec3(light);ALPHA=alpha;
 EMISSION=vec3(.50,.025,.02)*rim*patch*.32;
 }

ALPHA *= support_envelope;

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




