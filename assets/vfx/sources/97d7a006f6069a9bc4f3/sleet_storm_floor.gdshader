shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D frost:repeat_enable,filter_linear;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
void fragment(){
 vec2 p=(UV-.5)*16.;float r=length(p);
 float n=texture(noise_tex,UV*3.).r;
 float f=texture(frost,UV*5.+vec2(.14,.38)).r;
 float edge=1.-smoothstep(6.9+n*.8,7.4+n*.6,r);
 float reveal=smoothstep(.15,1.,weather_age)*(1.-smoothstep(3.,4.,weather_age));
 float veins=smoothstep(.58,.77,f)*(.18+.2*n);
 ALBEDO=mix(vec3(.10,.27,.40),vec3(.50,.68,.79),veins*1.6);
 ALPHA=edge*(.13+.15*smoothstep(.25,.65,n)+veins)*reveal;
}

