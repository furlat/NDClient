shader_type canvas_item;
render_mode blend_disabled;
#include "res://assets/vfx/sources/4c760993d5658e0620ca/cie_d65_v1.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D palette_texture : repeat_disable, filter_nearest;
uniform int palette_count = 24;
uniform float pixel_size_px : hint_range(1.0, 32.0, 1.0) = 8.0;
uniform float color_boost : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float alpha_luma_floor : hint_range(0.0, 0.2, 0.001) = 0.006;
uniform float alpha_luma_ceiling : hint_range(0.0, 0.4, 0.001) = 0.055;
uniform float glass_alpha_floor : hint_range(0.0, 0.4, 0.001) = 0.120;
uniform float glass_alpha_ceiling : hint_range(0.0, 0.6, 0.001) = 0.400;
uniform float glass_alpha_strength : hint_range(0.0, 1.0, 0.01) = 0.95;

uniform float output_opacity = 1.0;

void fragment() {
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 pixel_uv = pixel_size_px / viewport_px;
	vec2 snapped_uv = (floor(SCREEN_UV / pixel_uv) + vec2(0.5)) * pixel_uv;
	vec4 source = texture(screen_texture, clamp(snapped_uv, vec2(0.0), vec2(1.0)));
	float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float reconstructed_alpha = smoothstep(alpha_luma_floor, alpha_luma_ceiling, luma);
	if (reconstructed_alpha <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec3 best_color = cie_nearest(clamp(source.rgb * color_boost, vec3(0.0), vec3(1.0)), palette_texture, palette_count, 0.0, 0.0);
		float glass_alpha = mix(1.0 - glass_alpha_strength, 1.0, smoothstep(glass_alpha_floor, glass_alpha_ceiling, luma));
		COLOR = vec4(best_color, reconstructed_alpha * glass_alpha * output_opacity);
	}
}
