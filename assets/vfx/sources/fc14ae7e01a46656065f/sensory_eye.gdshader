shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform int kind=0;
uniform sampler2D source_noise: repeat_enable,filter_linear;
float stroke(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float t=support_clock;
 float opened=smoothstep(0.08,0.60,t);
 float x=clamp(p.x,-0.78,0.78);
 float bow=(kind==2?0.52:0.43)*(1.0-pow(x/0.78,2.0));
 float d=10.0;
 if(abs(p.x)<0.8)d=min(abs(p.y-bow),abs(p.y-mix(bow,-bow,opened)));
 d=min(d,stroke(p,vec2(.77,0),vec2(.96,-.17)));
 d=min(d,stroke(p,vec2(-.77,0),vec2(-.95,-.12)));
 float iris=10.0;
 float r=length(p);
 float angle=atan(p.y,p.x);
 float settle=(1.0-smoothstep(.45,1.1,t))*.8;
 float phase=t*1.570796327;
 bool interior=abs(p.x)<.65&&p.y<bow-.065&&p.y>mix(bow,-bow,opened)+.065;
 if(interior){
  if(kind==1){
   // Broad round pupil with a single crescent, never a cat-eye slit.
   float radius=.25+.014*sin(phase);
   if(p.x>.035)iris=abs(r-radius);
  }else if(kind==0){
   // Two diagonal iris accents leave a round, explicit dark centre.
   float a=angle+settle+0.65;
   if(cos(a*2.0)>.58)iris=abs(r-.30);
  }else{
   // Three isolated triangularly arranged marks; preserve gaps to the eyelids.
   float c=cos(settle),s=sin(settle);
   vec2 v=mat2(vec2(c,-s),vec2(s,c))*p;
   iris=min(length(v-vec2(0.0,-.25)),min(length(v-vec2(-.27,.18)),length(v-vec2(.27,.18))))-.035;
  }
 }
 float edge=1.0-smoothstep(kind==2?.040:.065,kind==2?.065:.10,d);
 float pattern=1.0-smoothstep(kind==2?.025:.045,kind==2?.045:.075,iris);
 float scan=.5+.5*sin(phase+p.x*3.0);
 float brightness=mix(.58,.83,scan);
 float leftcurve=-.57+.14*sin(p.y*4.5+phase);
 float rightcurve=.60+.12*sin(p.y*4.0-phase+1.0);
 float left=(1.0-smoothstep(.065,.12,abs(p.x-leftcurve)))*smoothstep(-.96,-.78,p.y)*(1.0-smoothstep(-.30,-.20,p.y));
 float right=(1.0-smoothstep(.055,.10,abs(p.x-rightcurve)))*smoothstep(.20,.30,p.y)*(1.0-smoothstep(.75,.93,p.y));
 float noise=texture(source_noise,UV*vec2(2.0,3.0)+vec2(sin(phase),cos(phase))*.20).r;
 float wisps=max(left,right)*mix(.55,.92,noise);
 float pupil=interior?(1.0-smoothstep(.13,.17,r)):0.0;
 ALBEDO=vec3(max(max(edge*brightness,pattern*.96),wisps*.75));
 if(pupil>.5)ALBEDO=vec3(.10);
 ALPHA=max(max(max(edge,pattern),wisps),pupil)*support_envelope;
}
