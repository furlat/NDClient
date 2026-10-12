shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled, unshaded;
#include "canvas_atlas.gdshaderinc"
// Source shadows and emissive overlays have no receiving normal. Keep their
// source/placement records intact, but omit their beauty pixels in this view.
void vertex() {
    VERTEX = UV;
}
void fragment() {
    COLOR = vec4(0.0);
}
