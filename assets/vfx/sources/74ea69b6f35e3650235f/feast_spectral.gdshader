shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform float clock=0.;uniform float ghost=0.;uniform float lightness=0.;varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 float lit=clamp(dot(normalize(NORMAL),normalize(vec3(-.4,.8,.6)))*.43+.48,0.,1.);
 float flow=pow(.5+.5*sin(local.y*17.+local.x*7.-clock*6.283185),14.);
 vec3 c=mix(vec3(.045,.085,.085),vec3(.37,.59,.57),lit);
 c=mix(c,vec3(.78,.95,.87),clamp(rim*.68+flow*.18+lightness*.4,0.,.85));
 ALBEDO=c;EMISSION=c*(.10+ghost*.16+lightness*.2);
 ALPHA=mix(.64+rim*.25+flow*.08,.15+rim*.48+flow*.14,ghost);
}
