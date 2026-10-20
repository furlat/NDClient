shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_opacity=1.0;
uniform vec4 field_shadow:source_color;
uniform vec4 field_highlight:source_color;

render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
uniform sampler2D flow_tex:repeat_enable,filter_linear;
uniform sampler2D cracks_tex:repeat_disable,filter_linear;
uniform int layer=0;
void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
if(length(support_world.xz)>12.0 || support_world.y<0.0) discard;

 vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);
 float n=texture(noise_tex,UV*3.5).r;
 vec2 curl=vec2(cos(a+support_clock*.32),sin(a+support_clock*.32))*.025;
 float flow=texture(flow_tex,UV*4.+curl+vec2(support_clock*.025,-support_clock*.018)).r;
 float front=smoothstep(.015,.37,support_clock);
 float reveal=1.-smoothstep(front-.03,front+.04,r+.035*(n-.5));
 float retire=smoothstep(1.02,1.75,support_clock);
 float dissolve=1.-smoothstep(1.-retire-.12,1.-retire+.06,n*.65+flow*.35);
 float live=reveal*dissolve*(1.-smoothstep(1.70,1.90,support_clock));
 float radialMask=1.-smoothstep(.94,1.,r);
 float cracks=texture(cracks_tex,UV).r;
 float vein=smoothstep(.71,.88,n)*smoothstep(.27,.43,flow);
 float pulse=1.-smoothstep(.018,.065,abs(r-front));
 // Filled base is the primary image. Veins, engraving and current remain part of it.
 float outer=1.-smoothstep(.010,.025,abs(r-.89));
 float inner=1.-smoothstep(.009,.024,abs(r-.57));
 float tooth=(1.-smoothstep(.08,.20,abs(sin(a*24.))))*smoothstep(.72,.76,r)*(1.-smoothstep(.81,.85,r));
 float rune=max(outer*.65,max(inner*.32,tooth*.5));
 vec3 dark=vec3(.018,.030,.048);vec3 wine=vec3(.11,.035,.040);vec3 ember=vec3(.55,.13,.075);
 if(layer==0){
  float lit=clamp(vein*.42+cracks*.38+rune*.75+pulse*.6,0.,1.);
  ALBEDO=mix(dark,wine,.15+.25*flow);ALBEDO=mix(ALBEDO,ember,lit*.50);
  EMISSION=vec3(.23,.045,.025)*(rune*.30+cracks*.20+pulse*.15);
  ALPHA=(.55+.12*flow+.08*lit)*radialMask*live;
 }else{
  // Connected low native surface, never detached petals or smoke spheres.
  float filaments=smoothstep(.54,.72,flow)*smoothstep(.36,.53,n);
  float face=.35+.65*max(0.,dot(normalize(NORMAL),normalize(vec3(.6,.8,.1))));
  ALBEDO=mix(field_shadow.rgb,field_highlight.rgb,filaments*.75)*face;
  EMISSION=vec3(.12,.034,.023)*filaments*.3;
  ALPHA=(.16+filaments*.30)*radialMask*live;
 }

ALPHA *= support_envelope * support_opacity;
}




