shader_type canvas_item;
render_mode blend_disabled;
#include "res://assets/vfx/sources/4c760993d5658e0620ca/cie_d65_v1.gdshaderinc"
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D palette_texture : repeat_disable, filter_nearest;
uniform sampler2D ramp_texture : repeat_disable, filter_nearest;
uniform int palette_count;
uniform int ramp_count;
uniform float rgb_block_pixels;
uniform float energy_floor;
uniform float energy_ceiling;
uniform float alpha_cutoff;
uniform float color_boost;
uniform float palette_energy_floor;
uniform float palette_luma_floor;
uniform float ramp_floor;
uniform float ramp_ceiling;
uniform bool ramp_uses_luma;
void fragment() {
	vec2 block_uv = vec2(rgb_block_pixels) * SCREEN_PIXEL_SIZE;
	vec2 snapped_uv = (floor(SCREEN_UV / block_uv) + vec2(0.5)) * block_uv;
	vec4 snapped = texture(screen_texture, clamp(snapped_uv, vec2(0.0), vec2(1.0)));
	float energy = max(max(snapped.r, snapped.g), snapped.b);
	float alpha = texture(screen_texture, SCREEN_UV).a * smoothstep(energy_floor, energy_ceiling, energy);
	if (alpha <= alpha_cutoff) {
		COLOR = vec4(0.0);
	} else {
		vec3 input_rgb = snapped.rgb;
		if (ramp_count >= 2) {
			float scalar = ramp_uses_luma ? dot(snapped.rgb, vec3(0.2126, 0.7152, 0.0722)) : energy;
			float position = clamp((scalar - ramp_floor) / (ramp_ceiling - ramp_floor), 0.0, 1.0) * float(ramp_count - 1);
			int first = int(floor(position));
			int second = min(first + 1, ramp_count - 1);
			vec3 a = texture(ramp_texture, vec2((float(first) + 0.5) / float(ramp_count), 0.5)).rgb;
			vec3 b = texture(ramp_texture, vec2((float(second) + 0.5) / float(ramp_count), 0.5)).rgb;
			input_rgb = mix(a, b, fract(position));
		}
		COLOR = vec4(cie_nearest(clamp(input_rgb * color_boost, vec3(0.0), vec3(1.0)), palette_texture, palette_count, palette_energy_floor, palette_luma_floor), alpha);
	}
}
