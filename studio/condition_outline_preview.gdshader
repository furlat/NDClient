shader_type canvas_item;
render_mode unshaded;
#include "res://presentation/condition_outline.gdshaderinc"
void fragment(){COLOR=condition_outline_colour(UV);}
