shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 source_colour:source_color=vec4(1.);
void fragment(){ALBEDO=source_colour.rgb;}
