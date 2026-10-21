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
// Original fixture actor-occlusion utility: RG16 little-endian horizontal
// painter contact, independent of the RG16BE/oct8 lighting packet above.
// Existing ordered draws provide one disjoint (lower, upper] contact band.
uniform bool use_actor_depth = false;
uniform sampler2D actor_depth_texture : filter_nearest, repeat_disable;
uniform vec4 actor_depth_rect;
uniform vec2 actor_depth_range;
uniform float actor_depth_scale;
uniform float actor_depth_origin;
uniform vec2 actor_depth_limits = vec2(-1e30, 1e30);
// Original continuous ground-residue motif source. These are per-tile numeric
// sampling operands prepared with the existing scenery owner, never a rebake.
uniform bool use_floor_motifs = false;
uniform int floor_motif_count = 0;
uniform vec4 floor_motif_placements[16];
uniform float floor_motif_noise[144];
uniform vec2 floor_motif_noise_phase;
uniform vec4 floor_motif_columns;
uniform vec4 floor_motif_widths;
uniform float floor_motif_height;
uniform int floor_motif_neighbors = 0;
uniform float floor_motif_opacity = 0.45;
// Supplied wall-image UV registrations. This multiplies only original colour;
// the base alpha, lighting packet, painter depth and membership stay unchanged.
uniform int wall_motif_face_count = 0;
uniform sampler2D wall_motif_texture0 : filter_nearest, repeat_disable;
uniform sampler2D wall_motif_texture1 : filter_nearest, repeat_disable;
uniform sampler2D wall_motif_texture2 : filter_nearest, repeat_disable;
uniform sampler2D wall_motif_texture3 : filter_nearest, repeat_disable;
uniform vec4 wall_motif_origins[4];
uniform vec4 wall_motif_axes[4];
uniform vec4 wall_motif_columns[4];
uniform vec4 wall_motif_widths[4];
uniform vec4 wall_motif_heights;
uniform vec4 wall_motif_reverse;
uniform vec4 wall_motif_opacity;
uniform vec4 wall_motif_counts;
uniform vec4 wall_motif_placements[24];
uniform float wall_motif_variants[24];
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
// Original component packets retain linear RGB normals and affine byte depth.
uniform bool use_component_depth = true;
uniform bool use_component_normals = true;
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

float actor_painter_depth(vec2 source_uv) {
    // UV addresses the unchanged full colour frame. The separately registered
    // utility rect selects that same animation frame/pose in its own atlas.
    vec2 pixel = floor(source_uv * actor_depth_rect.zw);
    vec2 bytes = round(texelFetch(actor_depth_texture, ivec2(actor_depth_rect.xy + pixel), 0).rg * 255.0);
    float encoded = bytes.r + bytes.g * 256.0;
    if (encoded == 0.0) return actor_depth_origin;
    return mix(actor_depth_range.x, actor_depth_range.y, (encoded - 1.0) / 65534.0)
        * actor_depth_scale + actor_depth_origin;
}

vec4 floor_motif_sample(vec2 pixel) {
    vec4 value = vec4(0.0);
    // Same gx-major/gy-minor overlap order as the original 32px source sampler.
    for (int i = 0; i < 16; i++) {
        if (i >= floor_motif_count) { break; }
        vec4 placement = floor_motif_placements[i];
        ivec2 p = ivec2(pixel - placement.xy);
        if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, ivec2(70)))) { continue; }
        int turn = int(placement.z);
        if (turn == 1) { p = ivec2(69 - p.y, p.x); }
        else if (turn == 2) { p = ivec2(69) - p; }
        else if (turn == 3) { p = ivec2(p.y, 69 - p.x); }
        ivec2 source = ivec2(floor(vec2(p) * vec2(floor_motif_widths[turn], floor_motif_height) / 70.0));
        source.x += int(floor_motif_columns[turn]);
        vec4 sampled = texelFetch(colour_texture, source, 0);
        float alpha = sampled.a * (191.0 / 255.0);
        float combined = alpha + value.a * (1.0 - alpha);
        if (combined > 0.0) {
            value.rgb = round((sampled.rgb * alpha + value.rgb * value.a * (1.0 - alpha)) / combined * 255.0) / 255.0;
        }
        value.a = round(combined * 255.0) / 255.0;
    }
    float distance = 99.0;
    int bit = 0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) { continue; }
            bool connected = (floor_motif_neighbors & (1 << bit)) != 0;
            bit++;
            if (connected) { continue; }
            vec2 edge = vec2(dx < 0 ? pixel.x : 31.0 - pixel.x, dy < 0 ? pixel.y : 31.0 - pixel.y);
            float exposed = dx == 0 ? edge.y : dy == 0 ? edge.x : length(edge);
            distance = min(distance, exposed);
        }
    }
    ivec2 noise = ivec2(floor((pixel + floor_motif_noise_phase) / 3.0));
    float threshold = floor_motif_noise[noise.x * 12 + noise.y];
    float edge_alpha = distance < threshold ? 0.0 : distance < threshold + 3.0 ? 110.0 / 255.0 : 1.0;
    value.a = round(value.a * edge_alpha * floor_motif_opacity * 255.0) / 255.0;
    return value;
}

vec4 wall_motif_texel(int face, ivec2 pixel) {
    if (face == 0) { return texelFetch(wall_motif_texture0, pixel, 0); }
    if (face == 1) { return texelFetch(wall_motif_texture1, pixel, 0); }
    if (face == 2) { return texelFetch(wall_motif_texture2, pixel, 0); }
    return texelFetch(wall_motif_texture3, pixel, 0);
}

vec3 wall_motif_colour(vec3 colour, vec2 pixel) {
    for (int face = 0; face < 4; face++) {
        if (face >= wall_motif_face_count) { break; }
        vec4 axes = wall_motif_axes[face];
        vec2 local = pixel - wall_motif_origins[face].xy;
        float determinant = axes.x * axes.w - axes.y * axes.z;
        vec2 uv = vec2(local.x * axes.w - local.y * axes.z, local.y * axes.x - local.x * axes.y) / determinant;
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { continue; }
        if (wall_motif_reverse[face] > 0.5) { uv.x = 1.0 - uv.x; }
        vec2 target = clamp(floor(uv * vec2(80.0, 192.0)), vec2(0.0), vec2(79.0, 191.0));
        vec4 value = vec4(0.0);
        for (int at = 0; at < 6; at++) {
            if (at >= int(wall_motif_counts[face])) { break; }
            int index = face * 6 + at;
            vec4 placement = wall_motif_placements[index];
            vec2 point = target - placement.xy;
            if (any(lessThan(point, vec2(0.0))) || any(greaterThanEqual(point, placement.zw))) { continue; }
            int column = int(wall_motif_variants[index]);
            if ((column % 2) != 0) { point.x = placement.z - 1.0 - point.x; }
            ivec2 source = ivec2(floor(point * vec2(wall_motif_widths[face][column], wall_motif_heights[face]) / placement.zw));
            source.x += int(wall_motif_columns[face][column]);
            vec4 sampled = wall_motif_texel(face, source);
            float alpha = sampled.a * (200.0 / 255.0);
            float combined = alpha + value.a * (1.0 - alpha);
            if (combined > 0.0) {
                value.rgb = round((sampled.rgb * alpha + value.rgb * value.a * (1.0 - alpha)) / combined * 255.0) / 255.0;
            }
            value.a = round(combined * 255.0) / 255.0;
        }
        colour = round(colour * (vec3(1.0) - (vec3(1.0) - value.rgb) * value.a * wall_motif_opacity[face]) * 255.0) / 255.0;
    }
    return colour;
}

// Nonzero registered depth qualifies the source surface; its normal is
// received on the painted plane, never at a reconstructed depth.
vec3 receiving_normal(vec2 pixel, mat3 world_to_canvas) {
    if (has_component_geometry) {
        if (!use_component_normals || abs(component_scale_x) <= 0.00001) return vec3(0.0, 0.0, 1.0);
        vec2 uv = frame_uv.xy + (pixel + vec2(0.5)) / material_cell_size * frame_uv.zw;
        vec4 depth = texture(component_depth, uv);
        vec4 normal = texture(component_normal, uv);
        bool valid = depth.a > 0.5 && normal.a > 0.5
            && texture(component_support, uv).r > 0.5 && texture(component_normal_valid, uv).r > 0.5;
        if (!valid) return vec3(0.0, 0.0, 1.0);
        vec3 n = normal.rgb * 2.0 - 1.0;
        n = normalize(vec3(n.x / component_scale_x, n.y, n.z));
        return vec3(n.x, -n.y, n.z);
    }
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
    vec4 sampled = use_floor_motifs ? floor_motif_sample(floor(texel * colour_size)) : environment_source_sample(texel);
    if (sampled.a <= 0.0) { discard; }
    vec2 pixel = floor(texel * colour_size);
    if (wall_motif_face_count > 0) { sampled.rgb = wall_motif_colour(sampled.rgb, pixel + vec2(0.5)); }
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
    if (use_actor_depth) {
        float painter_depth = actor_painter_depth(texel);
        // Exactly one band retains each original pixel. Coplanar pixels sit
        // behind the peer billboard, as in the original painter partition.
        if (painter_depth <= actor_depth_limits.x || painter_depth > actor_depth_limits.y) { discard; }
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
