shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://assets/vfx/sources/d761107faea637232d05/material.gdshaderinc"
uniform sampler2D weapon_pure_source : source_color, filter_nearest, repeat_disable;
uniform sampler2D weapon_pure_source_normals : filter_nearest, repeat_disable;
uniform sampler2D weapon_pure_normal_valid : filter_nearest, repeat_disable;
uniform sampler2D weapon_pure_support : filter_nearest, repeat_disable;
uniform vec4 weapon_pure_frame = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool weapon_pure_has_normals = false;
uniform bool weapon_pure_has_normal_valid = false;
uniform bool weapon_pure_has_support = false;
void fragment() {
    vec2 source_uv = weapon_pure_frame.xy + UV * weapon_pure_frame.zw;
    vec4 source = texture(weapon_pure_source, source_uv);
    vec3 normal = vec3(0.0, 0.0, 1.0);
    if (weapon_pure_has_normals) {
        vec4 packet = texture(weapon_pure_source_normals, source_uv);
        bool valid = packet.a > 0.5;
        if (weapon_pure_has_normal_valid)
            valid = valid && texture(weapon_pure_normal_valid, source_uv).r > 0.5;
        if (weapon_pure_has_support)
            valid = valid && texture(weapon_pure_support, source_uv).r > 0.5;
        vec3 decoded = packet.rgb * 2.0 - 1.0;
        if (valid && length(decoded) > 0.001) normal = normalize(decoded);
    }
    ALBEDO = weapon_pure_colour(source.rgb, UV, normal);
    ALPHA = source.a;
}
