shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D donor_noise:repeat_enable,filter_linear;
uniform sampler2D donor_stars:repeat_enable,filter_linear;
uniform float door_clock=0.;
uniform float door_envelope=1.;
uniform int style=0;
void fragment(){
 vec3 world=(INV_VIEW_MATRIX*vec4(VERTEX,1.)).xyz;
 // Disjoint native depth halves. The dark recess stays behind the threshold.
 if(style!=1 && dot(world,vec3(.70710678,0.,.70710678)) SIDE_COMPARE 0.)discard;
 if(style==1 && FRONT_CAPTURE)discard;
 float n=texture(donor_noise,UV*vec2(8.,2.)+vec2(-.13,.11)*door_clock).r;
 float light=.14+.42*pow(n,2.)+.25*pow(.5+.5*sin(UV.x*70.-door_clock*5.),8.);
 float alpha=door_envelope;
 if(style==1){
  vec2 p=vec2((UV.x-.5)*1.78,(1.-UV.y)*3.02+.06);
  float cap=length(vec2(p.x,max(0.,p.y-2.20))/.89);
  if(cap>1.)discard;
  float edge=pow(clamp(cap,0.,1.),12.);
  float dust=pow(texture(donor_noise,UV*vec2(5.,7.)+vec2(.03,-.09)*door_clock).r,18.);
  light=.008+.024*n+edge*.12+dust*.36;
  alpha=.94*door_envelope;
 }
 if(style==2){light=.10+.18*n;alpha=.64*door_envelope;}
 if(style==3){light=.64;alpha=texture(donor_stars,UV).r*COLOR.a*door_envelope;}
 ALBEDO=vec3(light);ALPHA=alpha;
}

