shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// Environment sprite, lit in its own pass with the receiving rules of the former
// light atlas: each source texel is lit once at its screen centre on the painted
// plane (height 0) from the light table. See lit_receiving.gdshaderinc.
#include "res://presentation/source_colour_environment.gdshaderinc"
#include "res://presentation/lit_receiving.gdshaderinc"
#include "res://presentation/native_scene_vertex.gdshaderinc"

uniform float authored_base_light = 1.0;
// Former 3D receiving policy; the painted plane receives max(N·L, 0).
uniform bool two_sided_receiver = false;
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
// Numeric RG16BE depth and octahedral BA normals: no sRGB or alpha conversion.
uniform sampler2D geometry_texture : filter_nearest, repeat_disable;
uniform sampler2D normal_texture : filter_nearest, repeat_disable;
uniform vec2 colour_size;
// Original door leaf painter-depth: RG16 little endian, distinct from lighting.
// Complementary passes retain source alpha behind and in front of its frame.
uniform int door_leaf_partition = 0;
uniform sampler2D door_depth_texture : filter_nearest, repeat_disable;
uniform vec4 door_depth_rect;
uniform vec2 door_depth_cell;
uniform vec2 door_depth_range;
uniform float door_depth_scale;
uniform float door_depth_offset;
uniform float door_frame_depth;
uniform sampler2D selection_mask : filter_nearest, repeat_disable;
uniform vec4 selection_rect;
uniform vec2 selection_scale = vec2(1.0);
uniform vec2 selection_offset = vec2(0.0);
uniform bool use_selection = false;
uniform bool invert_selection = false;
uniform int selection_kind = 0;
uniform vec4 rgba_min = vec4(0.0);
uniform vec4 rgba_max = vec4(1.0);
uniform vec4 selection_values = vec4(255.0);
uniform bool has_geometry = true;
uniform vec4 geometry_rect;
uniform vec4 normal_rect;
uniform vec2 sample_scale;
uniform vec2 sample_offset;
uniform vec2 sample_center;
uniform vec2 normal_scale;
uniform vec2 normal_offset;
uniform mat3 pixel_to_ray;
uniform vec3 ray_direction;
uniform vec2 depth_range;
uniform mat4 source_to_local;
uniform mat3 normal_to_local;
uniform mat4 local_to_world;
uniform mat3 local_normal_to_world;
uniform bool use_source_depth = true;
uniform bool use_source_normals = true;
// Published terrain neighbours (GroundReceiving.mask), in world +X,+Z,-X,-Z
// order. A skirt facing an equal/higher connected tile is an interior interface,
// not an exposed return; it receives with the horizontal top plane. World X/Z
// are grid cells; the texture holds the highest eligible terrain step per cell.
global uniform sampler2D ground_supports;
global uniform vec4 ground_supports_rect;
uniform bool ground_receiver = false;

float ground_support(vec2 cell) {
    vec2 at = cell - ground_supports_rect.xy;
    if (any(lessThan(at, vec2(0.0))) || any(greaterThanEqual(at, ground_supports_rect.zw))) return -1e30;
    return texelFetch(ground_supports, ivec2(at), 0).r;
}

int ground_mask(vec3 contact) {
    vec2 cell = round(contact.xz);
    float own = ground_support(cell);
    int mask = 0;
    if (ground_support(cell + vec2(1.0, 0.0)) >= own) mask |= 1;
    if (ground_support(cell + vec2(0.0, 1.0)) >= own) mask |= 2;
    if (ground_support(cell + vec2(-1.0, 0.0)) >= own) mask |= 4;
    if (ground_support(cell + vec2(0.0, -1.0)) >= own) mask |= 8;
    return mask;
}

varying vec3 instance_origin;
varying float scenery_visibility;
varying flat int join_mask;
void vertex() {
    instance_origin = MODEL_MATRIX[3].xyz;
    scenery_visibility = use_instance_visibility ? INSTANCE_CUSTOM.r : current_visibility;
    // Batched floors are terrain rows; other sprites say so per source.
    join_mask = (ground_receiver || use_instance_visibility) ? ground_mask(MODEL_MATRIX[3].xyz) : 0;
    native_scene_model_basis = mat3(MODEL_MATRIX);
    mat3 screen = lit_screen_quad(VERTEX, UV, PROJECTION_MATRIX * MODELVIEW_MATRIX);
    source_screen_origin = screen[0].xy; source_screen_axis_x = screen[1].xy; source_screen_axis_y = screen[2].xy;
}

vec3 oct_decode(vec2 encoded) {
    vec2 f = encoded * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

// Nonzero registered depth qualifies the source surface; its normal is
// received on the painted plane, never at a reconstructed depth.
vec3 receiving_normal(vec2 pixel, mat3 world_to_canvas) {
    vec2 gp = floor(pixel * sample_scale + sample_offset);
    bool in_packet = all(greaterThanEqual(gp, vec2(0.0))) && all(lessThan(gp, geometry_rect.zw));
    vec4 packed = vec4(0.0);
    if (has_geometry && in_packet) { packed = texelFetch(geometry_texture, ivec2(geometry_rect.xy + gp), 0); }
    float code = round(packed.r * 255.0) * 256.0 + round(packed.g * 255.0);
    if (!has_geometry || !in_packet || code <= 0.0 || !use_source_normals) return vec3(0.0, 0.0, 1.0);
    vec2 np = floor(pixel * normal_scale + normal_offset);
    if (!all(greaterThanEqual(np, vec2(0.0))) || !all(lessThan(np, normal_rect.zw))) return vec3(0.0, 0.0, 1.0);
    vec2 encoded = texelFetch(normal_texture, ivec2(normal_rect.xy + np), 0).ba;
    vec3 world_normal = normalize(local_normal_to_world * normal_to_local * oct_decode(encoded));
    if (join_mask != 0 && abs(world_normal.y) < 0.01 && max(abs(world_normal.x), abs(world_normal.z)) > 0.99) {
        int side = abs(world_normal.x) > abs(world_normal.z) ? (world_normal.x > 0.0 ? 1 : 4) : (world_normal.z > 0.0 ? 2 : 8);
        if ((join_mask & side) != 0) { world_normal = vec3(0.0, 1.0, 0.0); }
    }
    return normalize(world_to_canvas * world_normal);
}

void fragment() {
    vec2 texel = lit_texel_uv(UV, colour_size);
    vec4 sampled = environment_source_sample(texel);
    if (sampled.a <= 0.0) { discard; }
    vec2 pixel = floor(texel * colour_size);
    if (door_leaf_partition != 0) {
        vec2 dp = floor(texel * door_depth_cell);
        vec2 bytes = round(texelFetch(door_depth_texture, ivec2(door_depth_rect.xy + dp), 0).rg * 255.0);
        float encoded = bytes.r + bytes.g * 256.0;
        float depth = encoded == 0.0 ? door_frame_depth :
            mix(door_depth_range.x, door_depth_range.y, (encoded - 1.0) / 65534.0) * door_depth_scale + door_depth_offset;
        // Coplanar/unregistered pixels belong to the back pass, exactly once.
        bool behind_frame = depth <= door_frame_depth;
        if (behind_frame != (door_leaf_partition < 0)) { discard; }
    }
    if (use_selection) {
        bool selected = false;
        if (selection_kind == 1) {
            // The sampler is raw: the bounds name original encoded bytes.
            vec4 value = round(sampled * 255.0);
            selected = all(greaterThanEqual(value, rgba_min)) && all(lessThanEqual(value, rgba_max));
        } else {
            vec2 mp = floor(pixel * selection_scale + selection_offset);
            bool valid = all(greaterThanEqual(mp, vec2(0.0))) && all(lessThan(mp, selection_rect.zw));
            if (valid) {
                float value = round(texelFetch(selection_mask, ivec2(selection_rect.xy + mp), 0).r * 255.0);
                selected = any(lessThan(abs(selection_values - vec4(value)), vec4(0.5)));
            }
        }
        if (selected == invert_selection) { discard; }
    }
    vec4 colour = environment_source_colour(sampled, scenery_visibility);
    float alpha = lit_stored_alpha(colour.a);
    if (alpha <= 0.0 || wall_opacity <= 0.0) { discard; }
    if (lit_wall_masked(SCREEN_UV)) { discard; }
    vec3 normal = receiving_normal(pixel, lit_world_to_canvas(INV_VIEW_MATRIX));
    if (light_normals) {
        // Source shadows have no receiving normal: omitted in this view.
        if (source_unlit) { discard; }
        colour.rgb = lit_unlit(normal * 0.5 + 0.5);
    } else if (source_unlit) {
        colour.rgb = lit_unlit(colour.rgb);
    } else {
        colour.rgb = lit_received(colour.rgb, lit_screen_uv(texel) * VIEWPORT_SIZE, normal);
    }
    ALBEDO = lit_albedo(colour.rgb, OUTPUT_IS_SRGB);
    ALPHA = alpha * wall_opacity;
    if (native_scene_enabled) {
        vec3 receiver;
        if (native_scene_receiver(texel, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, instance_origin, receiver)) {
            LIGHT_VERTEX = receiver;
        }
    }
}
