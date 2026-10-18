shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
uniform int style=0;
uniform int mode=0;
void fragment(){
 float n=texture(noise_tex,UV*vec2(2.,5.)+vec2(.02,-TIME*.45)).r;
 vec3 scarlet=vec3(.78,.06,.045);vec3 bone=vec3(.95,.81,.62);
 if(mode==2){scarlet=vec3(.055,.31,.90);bone=vec3(.61,.84,1.);}
 if(style==0){
  float edge=1.-smoothstep(.06,.22,min(UV.x,1.-UV.x));
  float face=smoothstep(.25,.38,n);float fade=smoothstep(0.,.065,TIME)*(1.-smoothstep(.40,.82,TIME));
  ALBEDO=mix(vec3(.13,.18,.22),scarlet,edge*.75);EMISSION=mix(scarlet,bone,edge*.30)*edge*(.25+.20*n);
  ALPHA=face*fade*(.7+.3*edge);
 } else {
  vec2 p=(UV-.5)*2.;float r=length(p);float a=atan(p.y,p.x);
  // An execution stroke or an interrupted-motion rune; no curse/heart badge.
  float vertical=1.-smoothstep(.035,.09,abs(p.x));
  float diag=1.-smoothstep(.04,.095,abs(abs(p.x)*.80+p.y-.14));
  float bar=1.-smoothstep(.03,.08,abs(p.y-.30));
  float shape=max(vertical*step(r,.75),diag*step(r,.82));
  if(mode==2){
   float rays=1.-smoothstep(.09,.18,abs(sin(a*4.)));
   shape=rays*smoothstep(.10,.18,r)*(1.-smoothstep(.58,.80,r));
  }
  float chip=smoothstep(.14,.25,n);
  float fade=smoothstep(0.,.025,TIME)*(1.-smoothstep(.16,.43,TIME));
  ALBEDO=mix(scarlet,bone,smoothstep(.65,.92,n));EMISSION=ALBEDO*(.4+.7*n);ALPHA=shape*chip*fade;
 }
}
