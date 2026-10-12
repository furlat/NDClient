shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
#define SOURCE_MODULAR
#include "source_colour_modular.gdshaderinc"
#include "canvas_received.gdshaderinc"
