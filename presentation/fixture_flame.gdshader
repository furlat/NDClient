shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// Authored flame pixels are emissive artwork: no ambient and no lights. They
// keep the former atlas storage (half or byte) and decode. Omitted in Normals.
#include "res://presentation/lit_receiving.gdshaderinc"
uniform sampler2DArray frames : filter_nearest, repeat_disable;
uniform int frame_index = 0;
// The registered torch sequence has an alpha-1 padding pedestal. Zero keeps
// other authored effects unchanged; remove only that measured floor, smoothly.
uniform float alpha_pedestal = 0.0;
void fragment() {
    if (light_normals) { discard; }
    vec2 texel = lit_texel_uv(UV, vec2(textureSize(frames, 0).xy));
    vec4 colour = texture(frames, vec3(texel, float(frame_index)));
    colour.a = max(0.0, (colour.a - alpha_pedestal) / (1.0 - alpha_pedestal));
    if (colour.a <= 0.0) { discard; }
    float alpha = lit_stored_alpha(colour.a);
    if (alpha <= 0.0 || wall_opacity <= 0.0) { discard; }
    ALBEDO = lit_albedo(lit_unlit(colour.rgb), OUTPUT_IS_SRGB);
    ALPHA = alpha * wall_opacity;
}
