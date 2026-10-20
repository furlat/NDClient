shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
// Reuse production frame/palette/outfit operations. Whole-copy opacity belongs
// after composition; reducing each slot's alpha exposes hidden outfit layers.
#include "res://assets/vfx/sources/8b80036d2399983b1265/source_colour_modular.gdshaderinc"
uniform bool echo_receiving_enabled = false;
uniform sampler2D echo_received : source_color, filter_nearest, repeat_disable;
uniform vec4 echo_receiving_region;
uniform vec4 echo_receiving_crop = vec4(0.0,0.0,1.0,1.0);
uniform float echo_light_cap = 0.0;
vec3 echo_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
void fragment() {
    vec4 colour = modular_source_colour(UV);
    if (colour.a <= 0.0) discard;
    vec3 irradiance = vec3(1.0);
    if (echo_receiving_enabled && all(greaterThanEqual(UV,echo_receiving_crop.xy))
            && all(lessThan(UV,echo_receiving_crop.xy+echo_receiving_crop.zw))) {
        vec2 cell_uv = (UV-echo_receiving_crop.xy)/echo_receiving_crop.zw;
        vec4 received = texture(echo_received,echo_receiving_region.xy+cell_uv*echo_receiving_region.zw);
        // Retained source coverage owns an old pose. A later receiving crop must
        // never erase a historical limb or weapon outside that later pose.
        if (received.a > 0.0) irradiance = max(received.rgb,vec3(0.0));
        float peak = max(irradiance.r,max(irradiance.g,irradiance.b));
        if (echo_light_cap > 0.0 && peak > echo_light_cap) irradiance *= echo_light_cap/peak;
    }
    ALBEDO = echo_decode(clamp(colour.rgb*irradiance,vec3(0.0),vec3(1.0)));
    ALPHA = colour.a;
}
