shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
#define SOURCE_ENVIRONMENT
#include "source_colour_environment.gdshaderinc"
#include "canvas_received.gdshaderinc"
