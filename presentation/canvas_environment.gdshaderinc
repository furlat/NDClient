#include "canvas_atlas.gdshaderinc"
// Native PointLight2D/DirectionalLight2D receiving. Original source registration
// still owns sampling/selection; projected vertices never move for lighting.
// CanvasModulate owns ambient. There is deliberately no custom light().

#include "source_colour_environment.gdshaderinc"
uniform float authored_base_light = 1.0;
varying vec4 instance_colour;
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
varying float scenery_visibility;
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
// Published terrain neighbours, in world +X,+Z,-X,-Z order. A skirt facing an
// equal/higher connected tile is an interior interface, not an exposed return.
// Keep its original alpha/depth; receive with the existing horizontal top plane.
uniform int ground_join_mask = 0;

// Rows are world right, screen-down, toward-camera. atlas_canvas_normal
// cancels native MODEL_MATRIX rotation after source-to-Canvas conversion.
uniform mat3 world_to_canvas;
uniform float canvas_pixels_per_unit = 90.509667991878;
void vertex() {
    atlas_receiving_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    atlas_inverse_normal_basis = atlas_normal_inverse(MODEL_MATRIX);
    vec2 local_uv = VERTEX / atlas_cell_size;
    VERTEX = UV;
    UV = source_crop.xy + local_uv * source_crop.zw;
    // Original 3D floor instance colors are white. Authored source_tint owns
    // color; native per-instance visibility remains independent of shared data.
    instance_colour = vec4(1.0);
    scenery_visibility = receiver_visibility;
    COLOR = vec4(1.0);
}

vec3 oct_decode(vec2 encoded) {
    vec2 f = encoded * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

void fragment() {
    VERTEX = atlas_receiving_pixel;
    LIGHT_VERTEX = vec3(atlas_receiving_pixel, 0.0);
    vec4 colour = environment_source_sample(UV);
    if (colour.a <= 0.0) { discard; }
    vec2 pixel = floor(UV * colour_size);
    if (door_leaf_partition != 0) {
        vec2 dp = floor(UV * door_depth_cell);
        vec2 bytes = round(texelFetch(door_depth_texture, ivec2(door_depth_rect.xy + dp), 0).rg * 255.0);
        float encoded = bytes.r + bytes.g * 256.0;
        float depth = encoded == 0.0 ? door_frame_depth :
            mix(door_depth_range.x,door_depth_range.y,(encoded-1.0)/65534.0)*door_depth_scale+door_depth_offset;
        // Coplanar/unregistered pixels belong to the back pass, exactly once.
        bool behind_frame = depth <= door_frame_depth;
        if (behind_frame != (door_leaf_partition < 0)) { discard; }
    }
    if (use_selection) {
        bool selected = false;
        if (selection_kind == 1) {
            // LDR Canvas samples original encoded bytes. The same bytes own
            // source-role selection and authored tint; normals are numeric data.
            vec4 value = round(colour * 255.0);
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
    vec2 gp = floor(pixel * sample_scale + sample_offset);
    bool in_packet = all(greaterThanEqual(gp, vec2(0.0))) && all(lessThan(gp, geometry_rect.zw));
    vec4 packed = vec4(0.0);
    if (has_geometry && in_packet) { packed = texelFetch(geometry_texture, ivec2(geometry_rect.xy + gp), 0); }
    float code = round(packed.r * 255.0) * 256.0 + round(packed.g * 255.0);
    vec3 receiving_normal = vec3(0.0,0.0,1.0);
    NORMAL = atlas_canvas_normal(receiving_normal);
    if (has_geometry && in_packet && code > 0.0) {
        // Nonzero registered depth qualifies the source surface. Native canvas
        // LIGHT_VERTEX.z is screen-normal height, not world elevation or raw ray
        // depth. Keep its painted-plane zero convention, like the character
        // receiver, until a shared light/receiver height convention is supplied.
        if (use_source_normals) {
            vec2 np = floor(pixel * normal_scale + normal_offset);
            bool normal_in_packet = all(greaterThanEqual(np, vec2(0.0))) && all(lessThan(np, normal_rect.zw));
            if (normal_in_packet) {
                vec2 encoded = texelFetch(normal_texture, ivec2(normal_rect.xy + np), 0).ba;
                vec3 world_normal = normalize(local_normal_to_world * normal_to_local * oct_decode(encoded));
                if (ground_join_mask != 0 && abs(world_normal.y) < 0.01 && max(abs(world_normal.x),abs(world_normal.z)) > 0.99) {
                    int side = abs(world_normal.x) > abs(world_normal.z) ? (world_normal.x > 0.0 ? 1 : 4) : (world_normal.z > 0.0 ? 2 : 8);
                    if ((ground_join_mask & side) != 0) { world_normal = vec3(0.0,1.0,0.0); }
                }
                receiving_normal = normalize(world_to_canvas * world_normal);
                NORMAL = atlas_canvas_normal(receiving_normal);
            }
        }
    }
    colour = environment_source_colour(colour, scenery_visibility);
#ifdef SHOW_SOURCE_NORMALS
    COLOR = vec4(receiving_normal*0.5+0.5,colour.a);
#else
    COLOR = vec4(store_irradiance ? vec3(1.0) : colour.rgb,colour.a);
#endif
}
