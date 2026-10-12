#include "source_colour_common.gdshaderinc"
uniform sampler2D colour_texture : filter_nearest, repeat_disable;
uniform vec4 colour_rect;
uniform vec4 source_tint = vec4(1.0);
uniform bool source_unlit = false;
uniform bool highlighted = false;
vec4 environment_source_sample(vec2 uv) {
    return texture(colour_texture, (colour_rect.xy + uv * colour_rect.zw) / vec2(textureSize(colour_texture, 0)));
}
vec4 environment_source_colour(vec4 colour, float visibility) {
    colour *= source_tint;
    colour.rgb = source_remembered_colour(colour.rgb, visibility);
    if (highlighted) { colour.rgb = mix(colour.rgb, vec3(0.2, 1.0, 0.7), 0.55); }
    return vec4(source_unlit ? vec3(0.0) : colour.rgb, colour.a);
}
