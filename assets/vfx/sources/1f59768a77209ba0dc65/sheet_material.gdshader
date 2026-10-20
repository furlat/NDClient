shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

#include "res://assets/vfx/sources/e4eb6fc0555192afd006/material.gdshaderinc"

uniform sampler2D weapon_auxiliary_source : source_color, filter_nearest, repeat_disable;
uniform sampler2D weapon_auxiliary_source_normals : filter_nearest, repeat_disable;
uniform sampler2D weapon_auxiliary_normal_valid : filter_nearest, repeat_disable;
uniform sampler2D weapon_auxiliary_support : filter_nearest, repeat_disable;
uniform vec4 weapon_auxiliary_frame = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool weapon_auxiliary_has_normals = false;
uniform bool weapon_auxiliary_has_normal_valid = false;
uniform bool weapon_auxiliary_has_support = false;

void fragment() {
    vec2 atlas_uv = weapon_auxiliary_frame.xy + UV * weapon_auxiliary_frame.zw;
    vec4 source = texture(weapon_auxiliary_source, atlas_uv);
    vec3 normal = vec3(0.0, 0.0, 1.0);
    if (weapon_auxiliary_has_normals) {
        vec4 packet = texture(weapon_auxiliary_source_normals, atlas_uv);
        bool valid = packet.a > 0.5;
        if (weapon_auxiliary_has_normal_valid)
            valid = valid && texture(weapon_auxiliary_normal_valid, atlas_uv).r > 0.5;
        if (weapon_auxiliary_has_support)
            valid = valid && texture(weapon_auxiliary_support, atlas_uv).r > 0.5;
        vec3 decoded = packet.rgb * 2.0 - 1.0;
        if (valid && length(decoded) > 0.001) normal = normalize(decoded);
    }
    ALBEDO = weapon_auxiliary_colour(source.rgb, UV, normal);
    // Unknown normal/support never erases known source colour.
    ALPHA = source.a;
}
