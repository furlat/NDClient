shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Viewport colour is premultiplied. Preserve its soft coverage; the Factory
// export's energy/alpha cutoffs and nearest-colour quantization are not native VFX.
uniform sampler2D native_colour : repeat_disable, filter_linear;
uniform sampler2D ramp_texture : repeat_disable, filter_linear;
uniform int ramp_count = 0;
uniform float ramp_floor = 0.0;
uniform float ramp_ceiling = 1.0;
uniform bool ramp_uses_luma = false;
#include "res://presentation/native_spell_finish.gdshaderinc"
void fragment() {
    vec4 source = texture(native_colour, UV);
    // Pure additive native materials carry RGB with zero coverage. Keep that
    // radiance, including when mixed with source-over effects in this viewport.
    COLOR = finish_native_spell(source,ramp_texture,ramp_count,ramp_floor,ramp_ceiling,ramp_uses_luma);
}
