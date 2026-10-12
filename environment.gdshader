shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
#include "res://presentation/source_lighting.gdshaderinc"

uniform sampler2D colour_texture : source_color, filter_nearest, repeat_disable;
uniform float authored_base_light = 1.0;
varying vec4 instance_colour;
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
varying float scenery_visibility;
vec3 remembered_colour(vec3 colour) {
    // Source alpha and picking masks are untouched by memory styling.
    float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
    return mix(mix(vec3(grey), colour, 0.35) * 0.62, colour, scenery_visibility);
}
// Numeric RG16BE depth and octahedral BA normals: no sRGB or alpha conversion.
uniform sampler2D geometry_texture : filter_nearest, repeat_disable;
uniform sampler2D normal_texture : filter_nearest, repeat_disable;
uniform vec2 colour_size;
uniform vec4 colour_rect;
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
uniform bool highlighted = false;
uniform float wall_opacity : hint_range(0.0,1.0) = 1.0;
uniform bool wall_mask_enabled = false;
uniform int wall_mask_id = 0;
uniform sampler2D wall_mask_texture : filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform bool source_unlit = false;
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

varying vec3 instance_origin;
void vertex() { instance_origin = MODEL_MATRIX[3].xyz; instance_colour = COLOR; scenery_visibility = use_instance_visibility ? INSTANCE_CUSTOM.r : current_visibility; }

vec3 oct_decode(vec2 encoded) {
    vec2 f = encoded * 2.0 - 1.0;
    vec3 n = vec3(f, 1.0 - abs(f.x) - abs(f.y));
    float t = clamp(-n.z, 0.0, 1.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

void fragment() {
    vec2 colour_uv = (colour_rect.xy + UV * colour_rect.zw) / vec2(textureSize(colour_texture, 0));
    vec4 colour = texture(colour_texture, colour_uv);
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
            // Compatibility samples encoded RGB; Forward+/Mobile linearize
            // source_color textures. The bounds always name original bytes.
            vec3 raw = colour.rgb;
            if (!OUTPUT_IS_SRGB) { raw = mix(colour.rgb * 12.92, 1.055 * pow(colour.rgb, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), colour.rgb)); }
            vec4 value = vec4(round(raw * 255.0), round(colour.a * 255.0));
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
    float opacity = wall_opacity;
    if (opacity <= 0.0) { discard; }
    // An opaque rear wall must not be erased by a later faded wall's mask.
    if (wall_mask_enabled && opacity < 1.0) {
        vec4 owner = texture(wall_mask_texture, SCREEN_UV);
        ivec3 bytes = ivec3(round(owner.rgb * 255.0));
        int later_wall = bytes.r + (bytes.g << 8) + (bytes.b << 16);
        if (owner.a > 0.5 && later_wall > wall_mask_id) {
            // The 2D mask and spatial draw can choose adjacent texels at a
            // subpixel edge. Only erase where later coverage surrounds this
            // pixel; retain original source-over at the boundary to avoid holes.
            ivec2 size = textureSize(wall_mask_texture, 0);
            ivec2 at = ivec2(SCREEN_UV * vec2(size));
            bool covered = true;
            for (int y = -1; y <= 1; y++) {
                for (int x = -1; x <= 1; x++) {
                    vec4 sample_owner = texelFetch(wall_mask_texture, clamp(at + ivec2(x,y), ivec2(0), size-1), 0);
                    ivec3 sample_bytes = ivec3(round(sample_owner.rgb * 255.0));
                    int sample_id = sample_bytes.r + (sample_bytes.g << 8) + (sample_bytes.b << 16);
                    if (sample_owner.a <= 0.5 || sample_id <= wall_mask_id) { covered = false; }
                }
            }
            if (covered) { discard; }
        }
    }
    vec2 gp = floor(pixel * sample_scale + sample_offset);
    bool in_packet = all(greaterThanEqual(gp, vec2(0.0))) && all(lessThan(gp, geometry_rect.zw));
    vec4 packed = vec4(0.0);
    if (has_geometry && in_packet) { packed = texelFetch(geometry_texture, ivec2(geometry_rect.xy + gp), 0); }
    float code = round(packed.r * 255.0) * 256.0 + round(packed.g * 255.0);
    vec3 light_position = VERTEX;
    if (has_geometry && in_packet && code > 0.0) {
        float ray_depth = mix(depth_range.x, depth_range.y, (code - 1.0) / 65534.0);
        vec3 source_position = pixel_to_ray * vec3(gp + sample_center, 1.0) + ray_direction * ray_depth;
        vec4 world_position = local_to_world * source_to_local * vec4(source_position, 1.0);
        world_position.xyz += instance_origin - local_to_world[3].xyz;
        if (use_source_depth) { light_position = (VIEW_MATRIX * world_position).xyz; }
        if (use_source_normals) {
            vec2 np = floor(pixel * normal_scale + normal_offset);
            bool normal_in_packet = all(greaterThanEqual(np, vec2(0.0))) && all(lessThan(np, normal_rect.zw));
            if (normal_in_packet) {
                vec2 encoded = texelFetch(normal_texture, ivec2(normal_rect.xy + np), 0).ba;
                vec3 world_normal = normalize(local_normal_to_world * normal_to_local * oct_decode(encoded));
                NORMAL = normalize(mat3(VIEW_MATRIX) * world_normal);
            }
        }
    }
    LIGHT_VERTEX = light_position;
    // Offline authored_base_light preserves the exploration reference. The live
    // adapter sets it to zero; receiving radiance then depends only on sources.
    colour *= source_tint * instance_colour;
    colour.rgb = remembered_colour(colour.rgb);
    ALBEDO = source_unlit ? vec3(0.0) : colour.rgb;
    EMISSION = highlighted ? mix(colour.rgb, vec3(0.2, 1.0, 0.7), 0.55) : colour.rgb * authored_base_light;
    ALPHA = colour.a * opacity;
    ROUGHNESS = 1.0;
}

void light() {
    DIFFUSE_LIGHT += receiving_diffuse(NORMAL, LIGHT) * ATTENUATION * LIGHT_COLOR / PI;
}
