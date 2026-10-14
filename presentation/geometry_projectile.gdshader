shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,depth_test_disabled,shadows_disabled;
#include "geometry_projectile.gdshaderinc"
void fragment(){vec4 colour=geometry_projectile_colour(UV);ALBEDO=colour.rgb;ALPHA=colour.a;}
