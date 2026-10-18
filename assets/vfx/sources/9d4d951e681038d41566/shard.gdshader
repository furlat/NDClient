shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable;
void fragment(){float n=texture(source_noise,UV*2.).r;ALBEDO=vec3(.035+.52*step(.72,n));ALPHA=.92;}
