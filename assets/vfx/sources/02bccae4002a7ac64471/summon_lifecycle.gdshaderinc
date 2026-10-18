uniform float gpu_summon_age=0.;
uniform int gpu_summon_kind=0;
uniform int gpu_summon_index=0;
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 bool cast=gpu_summon_kind==3;
 int quarter=gpu_summon_index/(cast ? 2:3);
 int lane_index=gpu_summon_index%(cast ? 2:3);
 float lane=float(lane_index);
 float u=vertex.x/28.; float edge=vertex.y;
 float base=float(quarter)*1.57079632679+lane*.31;
 float contract=gpu_summon_kind==1 ? 1.-smoothstep(.28,1.24,gpu_summon_age)*.77 : .58+.42*smoothstep(0.,.46,gpu_summon_age);
 float radius_base=.58+lane*.135;
 if(cast){radius_base=.15+lane*.04;contract=1.;}
 float rotation=gpu_summon_age*(gpu_summon_kind==1 ? -1.15:.95);
 float arc_length=1.08+lane*.12;
 if(gpu_summon_kind==2){radius_base*=1.+smoothstep(.12,.60,gpu_summon_age)*.25;arc_length*=1.-smoothstep(.17,.63,gpu_summon_age)*.7;}
 float theta=base+rotation+u*arc_length;
 float radius=radius_base*contract*(1.+.07*sin(u*5.+lane));
 float h=.05+(lane*.18+u*.55)*smoothstep(.05,.52,gpu_summon_age);
 if(gpu_summon_kind==1)h=.13+(.30+u*.76)*(1.-smoothstep(.62,1.34,gpu_summon_age));
 if(cast)h=(u-.5)*.27;
 if(gpu_summon_kind==2)h=.4+u*.30;
 float width=(.07+lane*.023)*pow(max(0.,sin(u*3.14159265359)),.55);
 if(cast)width*=.70;
 vertex=vec3(cos(theta)*radius,h+edge*width,sin(theta)*radius);
}
