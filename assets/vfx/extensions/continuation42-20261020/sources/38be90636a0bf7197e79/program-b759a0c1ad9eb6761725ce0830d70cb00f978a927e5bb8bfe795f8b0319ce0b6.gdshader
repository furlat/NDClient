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
 uniform float age=0.;uniform float env=1.;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform float Intensity = 1.0;
uniform sampler2D Texture_Add : source_color, hint_default_black, repeat_disable;
uniform bool Enable_Distortion = true;
uniform float Dist_Zoom_Strenght = 1.0;
uniform float Diost_repeat_strenght = 1.0;
uniform vec2 Distortion_Speed_XY = vec2(0.000000, 0.000000);
uniform sampler2D Distortion_Texture : source_color;
uniform float Distortion_Attenuation = 5.0;
uniform float Zoom_Strenght = 1.0;
uniform float repeat = 1.0;
uniform vec2 Speed_XY = vec2(0.000000, 0.000000);
uniform sampler2D Texture_Main : source_color, filter_linear;
uniform float Power = 1.0;
uniform sampler2D Texture_Substract : source_color, hint_default_black, filter_linear, repeat_disable;
uniform float Proximity_Fade = 0.10000000149012;
uniform sampler2D depth_tex_frg_30 : hint_depth_texture;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform float Transparency : hint_range(0.0, 1.0) = 1.0;



void fragment() {vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
// FloatParameter:54
	float n_out54p0 = Intensity;


	vec4 n_out45p0;
// Texture2D:45
	n_out45p0 = texture(Texture_Add, UV);
	float n_out45p1 = n_out45p0.r;


// BooleanParameter:40
	bool n_out40p0 = Enable_Distortion;


// Input:17
	vec2 n_out17p0 = UV;


// FloatParameter:28
	float n_out28p0 = Dist_Zoom_Strenght;


// FloatParameter:27
	float n_out27p0 = Diost_repeat_strenght;


	vec2 n_out29p0;
// UVPolarCoord:29
	vec2 n_in29p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = UV - n_in29p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out29p0 = vec2(__radius * n_out28p0, __angle * n_out27p0);
	}


// Input:23
	float n_out23p0 = (vfx_package_seconds()+vfx_package_offset_age);


// Vector2Parameter:24
	vec2 n_out24p0 = Distortion_Speed_XY;


// VectorOp:25
	vec2 n_out25p0 = vec2(n_out23p0) * n_out24p0;


// UVFunc:26
	vec2 n_in26p1 = vec2(1.00000, 1.00000);
	vec2 n_out26p0 = n_out25p0 * n_in26p1 + n_out29p0;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Distortion_Texture, n_out26p0);
	float n_out19p1 = n_out19p0.r;


// FloatParameter:21
	float n_out21p0 = Distortion_Attenuation;


// FloatOp:20
	float n_out20p0 = n_out19p1 / n_out21p0;


// VectorOp:22
	vec2 n_out22p0 = n_out17p0 + vec2(n_out20p0);


// Input:42
	vec2 n_out42p0 = UV;


	vec2 n_out41p0;
// Switch:41
	n_out41p0 = mix(n_out42p0, n_out22p0, float(n_out40p0));


// FloatParameter:13
	float n_out13p0 = Zoom_Strenght;


// FloatParameter:14
	float n_out14p0 = repeat;


	vec2 n_out2p0;
// UVPolarCoord:2
	vec2 n_in2p1 = vec2(0.50000, 0.50000);
	{
		vec2 __dir = n_out41p0 - n_in2p1;
		float __radius = length(__dir) * 2.0;
		float __angle = atan(__dir.y, __dir.x) * 1.0 / (PI * 2.0);
		n_out2p0 = vec2(__radius * n_out13p0, __angle * n_out14p0);
	}


// Input:5
	float n_out5p0 = (vfx_package_seconds()+vfx_package_offset_age);


// Vector2Parameter:7
	vec2 n_out7p0 = Speed_XY;


// VectorOp:6
	vec2 n_out6p0 = vec2(n_out5p0) * n_out7p0;


// UVFunc:4
	vec2 n_in4p1 = vec2(1.00000, 1.00000);
	vec2 n_out4p0 = n_out6p0 * n_in4p1 + n_out2p0;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Texture_Main, n_out4p0);
	float n_out9p1 = n_out9p0.r;


// FloatParameter:16
	float n_out16p0 = Power;


// FloatOp:15
	float n_out15p0 = pow(n_out9p1, n_out16p0);


// FloatOp:46
	float n_out46p0 = n_out45p1 + n_out15p0;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Texture_Substract, UV);
	float n_out11p1 = n_out11p0.r;


// FloatOp:12
	float n_out12p0 = n_out46p0 - n_out11p1;


// FloatParameter:32
	float n_out32p0 = Proximity_Fade;


	float n_out30p0;
// ProximityFade:30
	{
		float __depth_tex = texture(depth_tex_frg_30, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out30p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out32p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:31
	float n_out31p0 = n_out12p0 * n_out30p0;


// Clamp:47
	float n_in47p1 = 0.00000;
	float n_in47p2 = 1.00000;
	float n_out47p0 = clamp(n_out31p0, n_in47p1, n_in47p2);


	vec4 n_out50p0;
// Texture2D:50
	n_out50p0 = texture(Color_1D_Gradient, vec2(n_out47p0));
	float n_out50p4 = n_out50p0.a;


// VectorOp:53
	vec3 n_out53p0 = vec3(n_out54p0) * vec3(n_out50p0.xyz);


// FloatParameter:52
	float n_out52p0 = Transparency;


// FloatOp:51
	float n_out51p0 = n_out50p4 * n_out52p0;


// Output:0
	ALBEDO = n_out53p0;
	ALPHA = n_out51p0;


ALPHA*=env;
// Original grayscale ALBEDO/EMISSION, noise, view seam and (vfx_package_seconds()+vfx_package_offset_age) are retained above.
// Original capture quantized max RGB after lighting/2x2 alpha pooling. Native
// surfaces expose these scalar inputs before lighting; that difference is explicit.
float finger_source_energy=clamp(max(max(ALBEDO.r+EMISSION.r,ALBEDO.g+EMISSION.g),ALBEDO.b+EMISSION.b),0.0,1.0);
float finger_source_index=floor(pow(finger_source_energy,finger_source_exponent)*float(finger_source_count-1)+0.5);
vec3 finger_source_encoded=texture(finger_source_palette,vec2((finger_source_index+0.5)/float(finger_source_count),0.5)).rgb;
ALBEDO=vec3(cie_linear_channel(finger_source_encoded.r),cie_linear_channel(finger_source_encoded.g),cie_linear_channel(finger_source_encoded.b));
EMISSION=vec3(0.0);
}




