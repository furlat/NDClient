uniform int gpu_summon_piece = 0;
uniform int gpu_summon_kind = 0;
uniform float gpu_summon_time = 0.0;
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	float u=point.x/28.0;
	float edge=point.y;
	bool cast=gpu_summon_kind==3;
	int lanes=cast?2:3;
	int quarter=gpu_summon_piece/lanes;
	float lane=float(gpu_summon_piece%lanes);
	float base=float(quarter)*3.14159265359/2.0+lane*.31;
	float contract=gpu_summon_kind==1?1.0-smoothstep(.28,1.24,gpu_summon_time)*.77:.58+.42*smoothstep(0.0,.46,gpu_summon_time);
	float radius=.58+lane*.135;
	if(cast){radius=.15+lane*.04;contract=1.0;}
	float rotation=gpu_summon_time*(gpu_summon_kind!=1?.95:-1.15);
	float span=1.08+lane*.12;
	if(gpu_summon_kind==2){radius*=1.0+smoothstep(.12,.60,gpu_summon_time)*.25;span*=1.0-smoothstep(.17,.63,gpu_summon_time)*.7;}
	float theta=base+rotation+u*span;
	radius*=contract*(1.0+.07*sin(u*5.0+lane));
	float height=.05+(lane*.18+u*.55)*smoothstep(.05,.52,gpu_summon_time);
	if(gpu_summon_kind==1)height=.13+(.30+u*.76)*(1.0-smoothstep(.62,1.34,gpu_summon_time));
	if(cast)height=(u-.5)*.27;
	if(gpu_summon_kind==2)height=.4+u*.30;
	float width=(.07+lane*.023)*pow(max(0.0,sin(u*3.14159265359)),.55);
	if(cast)width*=.70;
	point=vec3(cos(theta)*radius,height+edge*width,sin(theta)*radius);
	normal=vec3(0.0,0.0,1.0);
	tangent=vec3(1.0,0.0,0.0);
	binormal=vec3(0.0,1.0,0.0);
}
