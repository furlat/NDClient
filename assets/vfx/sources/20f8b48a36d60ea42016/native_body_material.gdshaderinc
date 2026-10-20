#ifndef NATIVE_BODY_MATERIAL_INCLUDED
#define NATIVE_BODY_MATERIAL_INCLUDED
// Live native material colour, evaluated by Godot in a small viewport.
// Coverage belongs exclusively to the painted character, never to this texture.
uniform bool native_body_enabled=false;
uniform sampler2D native_body_surface:filter_linear,repeat_disable;
uniform float native_body_strength=0.0;
uniform sampler2D native_body_ramp:filter_linear,repeat_disable;
uniform int native_body_ramp_count=0;
uniform float native_body_ramp_floor=0.0;
uniform float native_body_ramp_ceiling=1.0;
uniform bool native_body_ramp_uses_luma=false;
#include "res://assets/vfx/sources/0bab3c9e7d3723da7e37/native_spell_finish.gdshaderinc"
vec3 native_body_colour(vec3 lit_colour,vec2 cell_uv) {
    if(!native_body_enabled || native_body_strength<=0.0)return lit_colour;
    vec4 surface=texture(native_body_surface,cell_uv);
    surface=finish_native_spell(surface,native_body_ramp,native_body_ramp_count,native_body_ramp_floor,native_body_ramp_ceiling,native_body_ramp_uses_luma);
    // A transparent viewport stores premultiplied colour. Pure additive native
    // materials can carry radiance with zero alpha. Neither changes body alpha.
    vec3 material_colour=surface.a>0.0001?surface.rgb/surface.a:surface.rgb;
    material_colour=mix(material_colour/12.92,pow((material_colour+.055)/1.055,vec3(2.4)),greaterThan(material_colour,vec3(.04045)));
    return mix(lit_colour,material_colour,native_body_strength);
}
#endif
