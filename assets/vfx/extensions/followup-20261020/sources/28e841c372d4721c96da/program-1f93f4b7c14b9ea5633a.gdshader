shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
uniform sampler2D detail_tex:repeat_enable,filter_linear;
uniform float age=0.;uniform float layer=0.;uniform float side=1.;
varying vec3 local;varying float radius;
void vertex(){
 local=VERTEX;
 float t=max(0.,age-layer*.055);
 float u=clamp((t-.1)/.64,0.,1.);
 radius=12.*(1.-pow(1.-u,2.4));
 VERTEX*=max(.015,radius*(1.-layer*.045));
}
void fragment(){
 if(local.y<0.)discard;
 vec3 p=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
 
 float t=max(0.,age-layer*.055);
 float envelope=smoothstep(.1,.18,t)*(1.-smoothstep(.67,1.62,t));
 vec3 n=normalize(local);
 vec2 flow=vec2(age*.16,-age*.29);
 float cloud=(texture(noise_tex,n.xy*2.8+flow+layer*.23).r+texture(noise_tex,n.zy*2.8-flow).r)*.5;
 float detail=texture(detail_tex,vec2(atan(n.z,n.x)/6.283185,n.y)*vec2(9.,3.)+flow*1.3).r;
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.5);
 float veins=pow(smoothstep(.37,.76,cloud),2.2);
 float erosion=smoothstep(.0,.17,cloud+detail*.17-smoothstep(.75,1.6,t)*.82);
 float ground=exp(-n.y*38.);
 float rays=pow(max(0.,sin(atan(n.z,n.x)*37.+layer*4.+cloud*5.)),22.)*(1.-smoothstep(.38,.92,n.y));
 float energy=clamp(veins*.8+rim*.65+ground*.27+rays*.38,0.,1.);
 // Sacred Flame family: bronze depth, ochre, gold and a small warm core.
 vec3 col=mix(vec3(.52,.31,.07),vec3(.97,.72,.21),smoothstep(.03,.50,energy));
 col=mix(col,vec3(1.,.925,.55),smoothstep(.52,1.,energy));
 ALBEDO=col;
 ALPHA=clamp((.06+veins*.40+rim*.40+rays*.28+ground*.16)*envelope*erosion*(1.-layer*.24),0.,.7);
}



