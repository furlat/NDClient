shader_type canvas_item;
render_mode unshaded;
#include "res://presentation/geometry_projectile.gdshaderinc"
void fragment(){COLOR=geometry_projectile_colour(UV);}
