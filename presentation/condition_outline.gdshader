shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,depth_test_disabled,shadows_disabled;
#include "condition_outline.gdshaderinc"
void fragment(){vec4 colour=condition_outline_colour(UV);ALBEDO=colour.rgb;ALPHA=colour.a;}
