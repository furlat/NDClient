shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform sampler2D authored_noise:repeat_enable,filter_linear;
uniform float clock=0.0;
uniform float layer=0.0;
uniform bool front=true;
void fragment(){
 vec3 w=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 float dep=dot(w,vec3(.70710678,0,.70710678));
 if((front&&dep<0.0)||(!front&&dep>=0.0))discard;
 float n=texture(authored_noise,vec2(UV.x*2.0+layer*.22,UV.y*2.0-clock*1.2)).r;
 float fine=texture(authored_noise,vec2(UV.x*19.0+layer*.1,UV.y*.6-clock*2.4)).r;
 float reach=smoothstep(.05,.42,clock);
 float root=smoothstep(0.0,.035,UV.y);
 float tip=reach*(.88+.12*n);
 float leading=1.0-smoothstep(tip-.16,tip,UV.y);
 float edge=.015+.06*n;
 float sides=smoothstep(edge,edge+.07,UV.x)*smoothstep(edge,edge+.07,1.0-UV.x);
 float tail=1.0-smoothstep(.62,1.15,clock+UV.y*.1);
 vec3 violet=vec3(.57,.39,.83);vec3 cyan=vec3(.44,.82,.89);vec3 coral=vec3(.94,.53,.60);vec3 amber=vec3(.95,.8,.47);
 float band=fract(UV.x*2.0+layer*.21);
 vec3 color=mix(violet,cyan,smoothstep(.1,.3,band));color=mix(color,coral,smoothstep(.4,.57,band));color=mix(color,amber,smoothstep(.72,.9,band));
 ALBEDO=color;
 ALPHA=(.60*smoothstep(.20,.66,n)+.07*smoothstep(.35,.65,fine))*root*leading*sides*tail*smoothstep(0.0,.09,clock);
}
