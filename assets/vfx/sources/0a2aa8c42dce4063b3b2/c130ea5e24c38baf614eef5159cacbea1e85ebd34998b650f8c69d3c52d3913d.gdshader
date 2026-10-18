shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_noise : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float seed = 0.0;
void vertex(){
 float phase=clock*3.14159265+seed;
 VERTEX.y+=.045*sin(UV.x*6.283+phase)*sin(UV.y*6.283-phase);
}
void fragment(){
 float phase=clock*3.14159265;
 vec2 drift=vec2(cos(phase),sin(phase))*.15;
 float n=texture(source_noise,UV*2.6+drift+seed).r;
 float n2=texture(source_noise,UV*5.1-drift*.6+seed).r;
 float radial=1.-smoothstep(.22,.50,length(UV-.5));
 float fold=pow(.5+.5*sin(UV.x*18.+UV.y*12.+n*7.+cos(phase)*2.),2.);
 ALBEDO=vec3(.26+.38*n+.20*fold);
 ALPHA=radial*(.065+.18*n*n+.055*n2*fold);
}
