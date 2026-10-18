shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D frost:repeat_enable,filter_linear;
void fragment(){
 vec2 p=(UV-.5)*24.;float r=length(p);float angle=abs(atan(p.y,max(p.x,.001)));
 float noise=texture(edge_noise,p*.22).r;float flake=texture(edge_noise,p*.85+vec2(.17,.4)).r;
 float boundary=(1.-smoothstep(.414+noise*.03,.46251225,angle))*(1.-smoothstep(11.35+noise*.30,12.,r));
 float onset=.10+p.x/22.;float local=cold_age-onset;
 float envelope=smoothstep(-.05,.07,local)*(1.-smoothstep(1.05,2.30,local));
 float lace=smoothstep(.62,.80,flake)*(.3+.7*noise);
 ALBEDO=mix(vec3(.17,.37,.49),vec3(.57,.75,.81),lace);
 ALPHA=boundary*envelope*(.08+.23*lace)*smoothstep(.25,.70,r);
}

