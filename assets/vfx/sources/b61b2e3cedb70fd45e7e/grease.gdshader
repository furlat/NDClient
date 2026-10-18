shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform sampler2D marble : repeat_enable;
uniform sampler2D normal_pattern : repeat_enable;
uniform float clock=0.0;
uniform float grow=1.0;
uniform float opacity=1.0;
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float phase=clock*3.14159265;
 vec2 drift=vec2(sin(phase),cos(phase))*.045;
 float n=texture(marble,UV*1.35+drift).r;
 float edge=max(abs(p.x),abs(p.y));
 float contour=0.91+0.065*sin(p.x*14.0+p.y*5.0)+0.025*sin(p.y*21.0-p.x*3.0);
 float radius=max(abs(p.x+0.08*sin(p.y*8.0)),abs(p.y));
 float mask=1.0-smoothstep(contour*grow-.025,contour*grow+.025,radius);
 float crease=texture(normal_pattern,UV+drift*.45).g;
 float bands=sin(p.x*5.0+p.y*8.0+sin(p.y*4.0+phase)*.3+sin(p.x*7.0)*.8);
 float streak=pow(smoothstep(.93,1.0,bands),2.0)*smoothstep(-.4,.8,p.y);
 float rim=(1.0-smoothstep(.008,.035,abs(radius-contour*grow+.028)))*(.3+.7*smoothstep(-.4,.6,sin(p.x*7.0+p.y*3.0)));
 float glint=max(streak*.5,rim*.85);
 vec3 dark=vec3(.17,.15,.13);vec3 mid=vec3(.32,.30,.25);vec3 light=vec3(.62,.59,.47);
 ALBEDO=mix(mix(dark,mid,n*.1),light,glint);
 ALPHA=mask*(.42+glint*.48)*opacity;
}
