shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_door_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D donor_noise:repeat_enable,filter_linear;
uniform sampler2D donor_stars:repeat_enable,filter_linear;
uniform float door_clock=0.;
uniform float door_envelope=1.;
uniform int style=0;
void fragment(){
 vec3 world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
 // Disjoint native depth halves. The dark recess stays behind the threshold.
 
 if(style==1 && false)discard;
 float n=texture(donor_noise,UV*vec2(8.,2.)+vec2(-.13,.11)*(vfx_package_seconds()+vfx_package_offset_door_clock)).r;
 float light=.14+.42*pow(n,2.)+.25*pow(.5+.5*sin(UV.x*70.-(vfx_package_seconds()+vfx_package_offset_door_clock)*5.),8.);
 float alpha=door_envelope;
 if(style==1){
  vec2 p=vec2((UV.x-.5)*1.78,(1.-UV.y)*3.02+.06);
  float cap=length(vec2(p.x,max(0.,p.y-2.20))/.89);
  if(cap>1.)discard;
  float edge=pow(clamp(cap,0.,1.),12.);
  float dust=pow(texture(donor_noise,UV*vec2(5.,7.)+vec2(.03,-.09)*(vfx_package_seconds()+vfx_package_offset_door_clock)).r,18.);
  light=.008+.024*n+edge*.12+dust*.36;
  alpha=.94*door_envelope;
 }
 if(style==2){light=.10+.18*n;alpha=.64*door_envelope;}
 if(style==3){light=.64;alpha=texture(donor_stars,UV).r*COLOR.a*door_envelope;}
 ALBEDO=vec3(light);ALPHA=alpha;
}



