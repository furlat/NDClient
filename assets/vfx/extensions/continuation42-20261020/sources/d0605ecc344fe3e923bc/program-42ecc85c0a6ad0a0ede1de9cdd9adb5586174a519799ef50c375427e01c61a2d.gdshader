shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_age=0.0;

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


uniform sampler2D finger_source_palette:filter_nearest,repeat_disable;
uniform int finger_source_count=6;
uniform float finger_source_exponent=1.15;

render_mode cull_disabled;
uniform sampler2D noise_tex:repeat_enable;
uniform float age=0.;uniform float env=1.;
varying vec3 bone_position;
void vertex(){bone_position=VERTEX;}
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<.045)discard;
 float n=texture(noise_tex,bone_position.xy*5.+bone_position.z*.71).r;
 float flow=1.-smoothstep(.03,.16,abs(sin(dot(bone_position,vec3(9.,11.,7.))-(vfx_package_seconds()+vfx_package_offset_age)*1.8+n*4.)));
 ALBEDO=vec3(.42+.08*n);ROUGHNESS=.70;METALLIC=0.;
 EMISSION=vec3(.10)*flow*smoothstep(.3,.8,(vfx_package_seconds()+vfx_package_offset_age));
 float seam=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),5.);
 EMISSION+=vec3(.20)*seam;
 ALPHA=env*smoothstep(-.1,.12,n+env-.8);

// Original grayscale ALBEDO/EMISSION, noise, view seam and (vfx_package_seconds()+vfx_package_offset_age) are retained above.
// Original capture quantized max RGB after lighting/2x2 alpha pooling. Native
// surfaces expose these scalar inputs before lighting; that difference is explicit.
float finger_source_energy=clamp(max(max(ALBEDO.r+EMISSION.r,ALBEDO.g+EMISSION.g),ALBEDO.b+EMISSION.b),0.0,1.0);
float finger_source_index=floor(pow(finger_source_energy,finger_source_exponent)*float(finger_source_count-1)+0.5);
vec3 finger_source_encoded=texture(finger_source_palette,vec2((finger_source_index+0.5)/float(finger_source_count),0.5)).rgb;
ALBEDO=vec3(cie_linear_channel(finger_source_encoded.r),cie_linear_channel(finger_source_encoded.g),cie_linear_channel(finger_source_encoded.b));
EMISSION=vec3(0.0);
}




