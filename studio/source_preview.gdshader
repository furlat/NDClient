shader_type canvas_item;
render_mode unshaded;
#include "res://presentation/source_colour_modular.gdshaderinc"
void fragment(){COLOR=modular_source_colour(UV);}
