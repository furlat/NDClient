shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D source_noise:repeat_enable,filter_linear;
uniform sampler2D source_wave:repeat_enable,filter_linear;
uniform int style=0;
void fragment(){
 if(style==2){
  vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);
  float edge=abs(r-(.65+.08*cos(a*6.)));
  float border=(1.-smoothstep(.035,.085,edge))*step(.18,fract(a*1.909859+TIME*.04));
  float slash=min(abs(p.x*.72+p.y),abs(p.x*.72-p.y));
  float runes=(1.-smoothstep(.025,.070,slash))*smoothstep(.18,.30,r)*(1.-smoothstep(.55,.70,r));
  float n0=texture(source_noise,UV*3.+vec2(0.,-TIME*.5)).r;
  float coverage=max(border,runes)*smoothstep(.18,.32,n0);
  float env=smoothstep(0.,.045,TIME)*(1.-smoothstep(.24,.50,TIME));
  ALBEDO=mix(vec3(.56,.035,.04),vec3(1.,.30,.21),n0);
  EMISSION=ALBEDO*(.7+1.5*n0);ALPHA=coverage*env;
 } else {
 float n=texture(source_noise,UV*vec2(4.,2.2)+vec2(.05,-.12)*TIME).r;
 float detail=texture(source_noise,UV*vec2(10.,7.)+vec2(-.07,.04)*TIME).r;
 float wave=texture(source_wave,UV*vec2(2.,1.)+vec2(.03,-.18)*TIME).r;
 float threshold=.34+.36*smoothstep(.50,1.30,TIME);
 float patch=smoothstep(threshold,threshold+.045,n)*smoothstep(.015,.13,wave);
 float sector=.5+.5*sin(UV.x*18.8495559+sin(UV.y*8.));
 patch*=smoothstep(.2,.5,sector);
 float rim=1.-smoothstep(.03,.075,abs(n-threshold));
 float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 float light=.12+.11*wave+.47*rim*patch;
 float alpha=patch*(.55+.36*detail);
 if(style==1){light=.16+.30*detail;alpha=.80;}
 ALBEDO=vec3(light);ALPHA=alpha;
 EMISSION=vec3(.50,.025,.02)*rim*patch*.32;
 }
}
