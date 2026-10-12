shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled, unshaded;
#include "canvas_atlas.gdshaderinc"

// Authored flame pixels are emissive artwork; native scene lights illuminate
// receivers separately. Only the registered torch's measured alpha-1 padding
// is removed; source RGB, frame selection and full-opacity pixels are unchanged.
uniform sampler2DArray frames : filter_nearest, repeat_disable;
uniform int frame_index = 0;
uniform float alpha_pedestal = 0.0;
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
    vec4 colour = texture(frames,vec3(UV,float(frame_index)));
    colour.a = max(0.0, (colour.a - alpha_pedestal) / (1.0 - alpha_pedestal));
    if (colour.a <= 0.0) { discard; }
    COLOR = colour;
}
