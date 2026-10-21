shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;
uniform float vfx_package_offset_support_age=0.0;

uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_disabled;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
uniform int kind=0;
uniform float glyph_phase=0.0;
uniform sampler2D gold_noise;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
float line(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float d=10.0;
 float close=smoothstep(0.15,0.48,(vfx_package_seconds()+vfx_package_offset_support_clock))*(1.0-smoothstep(3.4,3.75,(vfx_package_seconds()+vfx_package_offset_support_clock)));
 if(kind==0){
  float x=clamp(p.x,-0.78,0.78);
  float bow=0.37*(1.0-pow(x/0.78,2.0));
  float lower=bow;
  float upper=mix(-bow,bow,close);
  if(abs(p.x)<0.8){d=min(abs(p.y-upper),abs(p.y-lower));}
  d=min(d,line(p,vec2(0.77,0),vec2(0.96,-0.15)));
  d=min(d,line(p,vec2(-0.77,0),vec2(-0.95,-0.10)));
  if(close>0.7){
   d=min(d,line(p,vec2(-0.48,0.23),vec2(-0.60,0.59)));
   d=min(d,line(p,vec2(-0.05,0.36),vec2(-0.06,0.74)));
   d=min(d,line(p,vec2(0.40,0.27),vec2(0.54,0.61)));
  }
  if(close<0.9&&p.y>upper&&p.y<lower){d=min(d,abs(length(p*vec2(1.0,0.7))-0.12));}
 }else if(kind==1){
  vec2 pts[9]=vec2[9](vec2(-0.55,-0.1),vec2(-0.56,-0.47),vec2(-0.31,-0.7),vec2(0.12,-0.72),vec2(0.39,-0.46),vec2(0.35,-0.05),vec2(0.03,0.28),vec2(-0.03,0.64),vec2(-0.31,0.71));
  for(int i=0;i<8;i++){d=min(d,line(p,pts[i],pts[i+1]));}
  d=min(d,line(p,vec2(-0.31,0.71),vec2(-0.49,0.48)));
  d=min(d,line(p,vec2(-0.32,-0.20),vec2(-0.25,-0.43)));
  d=min(d,line(p,vec2(-0.25,-0.43),vec2(0.05,-0.39)));
  d=min(d,line(p,vec2(0.05,-0.39),vec2(0.07,-0.13)));
  d=min(d,line(p,vec2(0.07,-0.13),vec2(-0.19,0.1)));
  if(close>0.6){d=min(d,line(p,vec2(0.14,0.18),vec2(0.60,-0.22)));}
  else{d=min(d,abs(length(p-vec2(-0.9,0))-0.20));}
 }else{
  float snap=1.0-0.2*smoothstep(2.6,2.8,(vfx_package_seconds()+vfx_package_offset_support_clock));
  p/=snap;
  d=min(line(p,vec2(-0.75,-0.55),vec2(-0.35,0.1)),line(p,vec2(0.75,-0.55),vec2(0.35,0.1)));
  d=min(d,line(p,vec2(-0.35,0.1),vec2(0,-0.5)));
  d=min(d,line(p,vec2(0,-0.5),vec2(0.35,0.1)));
  d=min(d,line(p,vec2(0,0.1),vec2(0,0.62)));
 }
 float mask=1.0-smoothstep(0.085,0.12,d);
 ALPHA=mask*support_envelope;
 float grain=texture(gold_noise,UV*2.0+vec2(sin(glyph_phase),cos(glyph_phase))*0.07).r;
 float facet=floor(grain*4.0)/3.0;
 float edge=1.0-smoothstep(0.01,0.075,d);
 ALBEDO=vec3(clamp(0.57+facet*0.20+edge*0.14,0.0,0.94));

ALPHA *= factory_occurrence_alpha;
}



