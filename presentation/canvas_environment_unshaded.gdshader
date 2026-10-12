shader_type canvas_item;
render_mode skip_vertex_transform, blend_disabled, unshaded;
// Select for source shadow/emissive roles; a uniform cannot bypass native light.
#include "canvas_environment.gdshaderinc"
