shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
uniform int style=0;
void fragment(){
 float n=texture(source_noise,UV*vec2(5.,3.)+vec2(.25,-.25)*support_clock).r;
 float n2=texture(source_noise,UV*vec2(9.,4.)+vec2(-.25,.25)*support_clock).r;
 float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 float crack=1.-smoothstep(.045,.105,abs(n-.47));
 float bands=.5+.5*sin(UV.x*26.+n2*6.+UV.y*12.-support_clock*5.);
 float patch=smoothstep(.48,.65,n);
 float light=.04+.40*crack+.18*pow(bands,8.);
 float alpha=patch*(.30+.46*crack)+edge*.12;
 if(style==0){
  float shoulders=sin(UV.y*3.14159);
  alpha*=shoulders*(.30+.70*smoothstep(.22,.65,n2));
  light=.045+.22*pow(bands,5.)+.25*crack;
 }
 if(style==2){
  alpha*=smoothstep(.15,.37,n2);
  light=.05+.54*crack+.15*edge;
 }
 if(style==4){alpha=max(patch*.80,crack*.90);light=.02+crack*.82;}
 ALBEDO=vec3(light);
 ALPHA=alpha;

ALPHA *= support_envelope;
}




