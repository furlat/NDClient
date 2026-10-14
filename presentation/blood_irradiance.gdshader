shader_type canvas_item;
render_mode blend_disabled;
uniform vec3 receiving_normal=vec3(0.,0.,1.);
void fragment(){NORMAL=receiving_normal;COLOR=vec4(1.);}
