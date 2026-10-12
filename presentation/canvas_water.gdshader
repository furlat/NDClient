shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled;
#include "canvas_atlas.gdshaderinc"
uniform vec2 actual_scene_viewport_size = vec2(1.0);
// Existing authored water graph, received by native Canvas lights.
// Port of the connected branches in the existing water material graph.
#include "source_colour_water.gdshaderinc"
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_visibility = false;
uniform vec3 canvas_instance_origin;
uniform mat3 world_to_canvas;
uniform float canvas_pixels_per_unit = 90.509667991878;
varying float scenery_visibility;
varying vec2 instance_shift;
varying vec3 instance_origin;
void vertex() {
    atlas_receiving_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    atlas_inverse_normal_basis = atlas_normal_inverse(MODEL_MATRIX);
    vec2 local_uv = VERTEX / atlas_cell_size;
    VERTEX = UV;
    UV = source_crop.xy + local_uv * source_crop.zw;
    COLOR = vec4(1.0);
    instance_origin = receiver_world_origin;
    scenery_visibility = receiver_visibility;
    instance_shift = water_source_shift(instance_origin);
}
void fragment() {
    VERTEX = atlas_receiving_pixel;
    LIGHT_VERTEX = vec3(atlas_receiving_pixel, 0.0);
    vec4 colour = water_source_colour(UV, instance_shift, atlas_receiving_pixel / actual_scene_viewport_size, scenery_visibility);
    if (colour.a <= 0.0) { discard; }
    NORMAL = atlas_canvas_normal(normalize(world_to_canvas * vec3(0.0,1.0,0.0)));
#ifdef SHOW_SOURCE_NORMALS
    COLOR = vec4(normalize(world_to_canvas*vec3(0.0,1.0,0.0))*0.5+0.5,colour.a);
#else
    COLOR = colour;
#endif
}
