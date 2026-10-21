shader_type canvas_item;
render_mode unshaded;
#include "res://presentation/source_colour_modular.gdshaderinc"
void fragment(){
    vec4 colour=modular_source_colour(UV);
    if(native_body_enabled) {
        vec3 linear_colour=mix(colour.rgb/12.92,pow((colour.rgb+.055)/1.055,vec3(2.4)),greaterThan(colour.rgb,vec3(.04045)));
        linear_colour=native_body_colour(linear_colour,UV);
        colour.rgb=mix(linear_colour*12.92,1.055*pow(max(linear_colour,vec3(0.0)),vec3(1.0/2.4))-.055,greaterThan(linear_colour,vec3(.0031308)));
    }
    COLOR=colour;
}
