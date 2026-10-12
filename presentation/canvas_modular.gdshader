shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled;
// One component per atlas cell, straight RGBA. 3D output owns painter order,
// final alpha and coverage; native Canvas lights own receiving radiance.
#include "canvas_atlas.gdshaderinc"
#include "source_colour_modular.gdshaderinc"
uniform float authored_base_light = 1.0;
// Preserve the original registration parameter interface. Receiving on the
// painted native Canvas plane does not reinterpret depth as light height.
uniform sampler2D component_depth : filter_nearest, repeat_disable;
uniform sampler2D component_normal : filter_nearest, repeat_disable;
uniform sampler2D component_support : filter_nearest, repeat_disable;
uniform sampler2D component_normal_valid : filter_nearest, repeat_disable;
uniform vec2 component_depth_range;
uniform float component_units = 0.0;
uniform float component_scale_x = 1.0;
uniform vec2 component_reconstruction_origin = vec2(64.0,96.0);
uniform float component_elevation = 0.7853981633974483;
uniform bool calibrated_component_receiver = true;
uniform bool has_component_geometry = false;
uniform bool use_component_depth = true;
uniform bool use_component_normals = true;
void vertex() {
    atlas_receiving_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    atlas_inverse_normal_basis = atlas_normal_inverse(MODEL_MATRIX);
    vec2 local_uv = VERTEX / atlas_cell_size;
    VERTEX = UV;
    UV = source_crop.xy + local_uv * source_crop.zw;
    COLOR = vec4(1.0);
}
void fragment() {
    VERTEX = atlas_receiving_pixel;
    LIGHT_VERTEX = vec3(atlas_receiving_pixel, 0.0);
    vec2 source_uv = frame_uv.xy + UV * frame_uv.zw;
    vec4 colour = modular_source_colour(UV);
    if (colour.a <= 0.0) { discard; }
    vec3 n = vec3(0.0,0.0,1.0);
    if (has_component_geometry && !shadow && use_component_normals && abs(component_scale_x)>0.00001) {
        vec4 depth = texture(component_depth,source_uv);
        vec4 normal = texture(component_normal,source_uv);
        bool valid = texture(component_support,source_uv).r>0.5
            && texture(component_normal_valid,source_uv).r>0.5
            && depth.a>0.5 && normal.a>0.5;
        if (valid) {
            // All RGB channels are linear numeric data; facing is already
            // baked. Inverse horizontal component scale applies exactly once.
            n = normal.rgb*2.0-1.0;
            n = normalize(vec3(n.x/component_scale_x,n.y,n.z));
        }
    }
    NORMAL = atlas_canvas_normal(vec3(n.x,-n.y,n.z));
#ifdef SHOW_SOURCE_NORMALS
    COLOR = vec4(vec3(n.x,-n.y,n.z)*0.5+0.5,colour.a);
#else
    COLOR = vec4(store_irradiance ? vec3(1.0) : colour.rgb,colour.a);
#endif
}
