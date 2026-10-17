shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
#include "res://presentation/light_table_linear.gdshaderinc"
uniform sampler2D effect_texture : source_color, filter_nearest, repeat_disable;
uniform bool receiving_enabled = false;
// Receiving: the source colour capture (coverage), its composition normals,
// and the screen pixel of capture texel 0. The light is the former lit Canvas
// page's: a white receiver over the converted ambient, lit by the room lights
// with linearly filtered cookies, stored as half floats.
uniform sampler2D native_colour : filter_nearest, repeat_disable;
uniform sampler2D native_normals : filter_nearest, repeat_disable;
uniform vec2 receiving_origin;
uniform float receiving_ambient = 0.18;
uniform bool receiving_room_lights = true;
uniform float light_cap = 0.0;
vec3 source_encode(vec3 value) {
    return mix(1.055*pow(value,vec3(1.0/2.4))-vec3(.055),12.92*value,lessThanEqual(value,vec3(.0031308)));
}
vec3 source_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
float receiving_half(float value) {
    return unpackHalf2x16(packHalf2x16(vec2(value, 0.0))).x;
}
// The capture texel nearest filtering picked for uv: floor(uv*size), or a
// neighbour where uv fell on a texel edge, found by its exact fetched values.
ivec2 receiving_texel(vec2 uv, vec4 colour, vec4 field) {
    ivec2 size = textureSize(native_colour, 0);
    ivec2 base = clamp(ivec2(floor(uv * vec2(size))), ivec2(0), size - 1);
    for (int i = 0; i < 9; i++) {
        ivec2 texel = clamp(base + ivec2(i % 3 == 1 ? -1 : (i % 3 == 2 ? 1 : 0), i / 3 == 1 ? -1 : (i / 3 == 2 ? 1 : 0)), ivec2(0), size - 1);
        if (texelFetch(native_colour, texel, 0) == colour && texelFetch(native_normals, texel, 0) == field) return texel;
    }
    return base;
}
vec3 receiving_light(vec2 uv) {
    vec4 colour = texture(native_colour, uv);
    if (colour.a <= 0.0) return vec3(0.0);
    vec4 field = texture(native_normals, uv);
    vec3 packed = source_decode(field.rgb) / max(field.a, 1.0 / 65535.0);
    vec3 normal = normalize(packed * 2.0 - 1.0);
    vec3 n = normalize(vec3(normal.x, -normal.y, normal.z));
    vec2 p = receiving_origin + vec2(receiving_texel(uv, colour, field)) + 0.5;
    vec3 light = receiving_room_lights ? table_light_linear(p, n, vec3(1.0), receiving_ambient) : vec3(receiving_ambient);
    return vec3(receiving_half(light.r), receiving_half(light.g), receiving_half(light.b));
}
uniform float opacity = 1.0;
void fragment() {
    vec4 value=texture(effect_texture,UV);
    if(receiving_enabled) {
        vec3 light=receiving_light(UV);
        float peak=max(light.r,max(light.g,light.b));
        if(light_cap>0.0 && peak>light_cap)light*=light_cap/peak;
        vec3 original=source_encode(clamp(value.rgb/max(value.a,1.0/65535.0),vec3(0.0),vec3(1.0)));
        ALBEDO=source_decode(clamp(original*light,vec3(0.0),vec3(1.0)));
    } else ALBEDO=value.rgb;
    ALPHA=value.a*opacity;
}
