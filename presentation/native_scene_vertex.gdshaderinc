// Opt-in spatial receiver coordinates for native scene effects. The existing
// Canvas atlas still owns colour, normals, opacity and the painted raster.
uniform bool native_scene_enabled = false;
uniform bool native_scene_plane = false;
uniform vec2 native_scene_pivot = vec2(64.0, 96.0);
uniform float native_scene_ground_height = 0.0;
uniform bool has_component_geometry = false;
uniform sampler2D component_depth : filter_nearest, repeat_disable;
uniform sampler2D component_support : filter_nearest, repeat_disable;
uniform sampler2D component_normal : filter_nearest, repeat_disable;
uniform sampler2D component_normal_valid : filter_nearest, repeat_disable;
uniform float component_scale_x = 1.0;
uniform vec2 component_depth_range;
uniform float component_units = 0.0;
uniform vec2 component_reconstruction_origin;
uniform float component_elevation;
#ifndef CAPPED_MODULAR
uniform vec4 frame_uv;
uniform vec2 material_cell_size = vec2(128.0);
#endif
varying mat3 native_scene_model_basis;

bool native_scene_receiver(vec2 source_uv, vec3 painted_view, mat4 view, mat4 inverse_view,
        vec3 world_origin, out vec3 point) {
    vec3 toward_camera = inverse_view[2].xyz;
    if (abs(toward_camera.y) < 0.00001) return false;
    if (native_scene_plane) {
        // The current production camera is orthographic. Intersect its ray,
        // not the upright painted quad, with this admitted floor's elevation.
        float z = (world_origin.y-inverse_view[3].y
            - inverse_view[0].y*painted_view.x-inverse_view[1].y*painted_view.y)/toward_camera.y;
        point = vec3(painted_view.xy, z);
        return true;
    }
    if (!has_component_geometry || component_units <= 0.0) return false;
    vec2 pixel = floor(source_uv * material_cell_size) + vec2(0.5);
    vec2 uv = frame_uv.xy + pixel / material_cell_size * frame_uv.zw;
    vec4 depth = texture(component_depth, uv);
    if (depth.a <= 0.5 || texture(component_support, uv).r <= 0.5) return false;
    float d = component_depth_range.x + (depth.r*255.0-32.0)
        * (component_depth_range.y-component_depth_range.x)/192.0;
    float height = ((component_reconstruction_origin.y-pixel.y)*cos(component_elevation)
        + d*sin(component_elevation))*component_units;
    // Native scene geometry uses the packet's actual optical height above its
    // authored ground. Shadow-caster compression is a separate presentation.
    height -= native_scene_ground_height;
    vec3 local = vec3(pixel.x-native_scene_pivot.x, native_scene_pivot.y-pixel.y, 0.0)*component_units;
    vec3 painted = mat3(inverse_view)*local;
    local.z = (height-painted.y)/toward_camera.y;
    // The sampled model basis already includes mirror and passage deformation;
    // apply it once, retaining the displayed origin and airborne lift.
    point = (view*vec4(world_origin + native_scene_model_basis*local, 1.0)).xyz;
    return true;
}
