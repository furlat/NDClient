shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// Modular actor layer, lit in its own pass with the receiving rules of the
// former light atlas: each cell texel is lit once at its screen centre on the
// painted plane (height 0) from the light table. See lit_receiving.gdshaderinc.
#define CAPPED_MODULAR
#include "res://presentation/source_colour_modular.gdshaderinc"
#include "res://presentation/lit_receiving.gdshaderinc"
// Native component packet: linear RGB normals + affine byte depth, with
// independent validity masks. It is not the environment RG16/oct packet.
#include "res://presentation/native_scene_vertex.gdshaderinc"
uniform float authored_base_light = 1.0;
uniform bool calibrated_component_receiver = true;
uniform bool use_component_depth = true;
uniform bool use_component_normals = true;
varying vec3 source_world_origin;
void vertex() {
    source_world_origin = MODEL_MATRIX[3].xyz;
    native_scene_model_basis = mat3(MODEL_MATRIX);
    mat3 screen = lit_screen_quad(VERTEX, UV, PROJECTION_MATRIX * MODELVIEW_MATRIX);
    source_screen_origin = screen[0].xy; source_screen_axis_x = screen[1].xy; source_screen_axis_y = screen[2].xy;
}
void fragment() {
    // Animated sheets keep one authored cell; texels snap to that cell grid.
    vec2 texel = lit_texel_uv(UV, material_cell_size);
    vec4 colour = modular_source_colour(texel);
    if (colour.a <= 0.0) { discard; }
    float alpha = lit_stored_alpha(colour.a);
    if (alpha <= 0.0 || wall_opacity <= 0.0) { discard; }
    vec2 source_uv = frame_uv.xy + texel * frame_uv.zw;
    vec3 n = vec3(0.0, 0.0, 1.0);
    if (has_component_geometry && !shadow && use_component_normals && abs(component_scale_x) > 0.00001) {
        vec4 depth = texture(component_depth, source_uv);
        vec4 normal = texture(component_normal, source_uv);
        bool valid = texture(component_support, source_uv).r > 0.5
            && texture(component_normal_valid, source_uv).r > 0.5
            && depth.a > 0.5 && normal.a > 0.5;
        if (valid) {
            // All RGB channels are linear numeric data; facing is already
            // baked. Inverse horizontal component scale applies exactly once.
            n = normal.rgb * 2.0 - 1.0;
            n = normalize(vec3(n.x / component_scale_x, n.y, n.z));
        }
    }
    vec3 canvas_normal = vec3(n.x, -n.y, n.z);
    if (light_normals) {
        if (shadow) { discard; }
        colour.rgb = lit_unlit(canvas_normal * 0.5 + 0.5);
    } else if (shadow) {
        colour.rgb = lit_unlit(colour.rgb);
    } else {
        colour.rgb = lit_received(colour.rgb, lit_screen_uv(texel) * VIEWPORT_SIZE, canvas_normal);
    }
    if (body_surface_enabled && body_surface_count > 0 && has_component_geometry) {
        vec3 surface_point;
        vec4 packet_normal = texture(component_normal, source_uv);
        if (packet_normal.a > .5 && texture(component_normal_valid, source_uv).r > .5
            && native_scene_receiver(texel, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, surface_point)) {
            vec3 sn = packet_normal.rgb * 2.0 - 1.0;
            sn = normalize(vec3(sn.x / (abs(component_scale_x) > .00001 ? component_scale_x : 1.0), sn.y, sn.z));
            vec3 horizontal = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
            vec3 up = vec3(0.0, cos(component_elevation), 0.0) - horizontal * sin(component_elevation);
            vec3 toward = horizontal * cos(component_elevation) + vec3(0.0, sin(component_elevation), 0.0);
            vec3 normal_world = normalize(mat3(INV_VIEW_MATRIX[0].xyz, up, toward) * sn);
            vec3 relative = (INV_VIEW_MATRIX * vec4(surface_point, 1.0)).xyz - source_world_origin;
            colour.rgb = apply_body_surface(colour.rgb, relative, normal_world, normalize(mat3(VIEW_MATRIX) * normal_world));
        }
    }
    colour.rgb = native_body_colour(colour.rgb, texel);
    ALBEDO = lit_albedo(colour.rgb, OUTPUT_IS_SRGB);
    ALPHA = alpha * wall_opacity;
    if (native_scene_enabled) {
        vec3 receiver;
        if (native_scene_receiver(texel, VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, source_world_origin, receiver)) {
            LIGHT_VERTEX = receiver;
        }
    }
}
