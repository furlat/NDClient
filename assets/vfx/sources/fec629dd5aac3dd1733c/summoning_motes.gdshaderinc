uniform float gpu_summon_time = 0.0;
uniform int gpu_summon_kind = 0;
uniform int gpu_summon_camera_quadrant = 0;
varying flat float gpu_mote_strength;

float gpu_source_envelope(float age) {
	if(gpu_summon_kind==0)return smoothstep(0.0,.30,age)*(1.0-smoothstep(.90,1.64,age));
	if(gpu_summon_kind==1)return smoothstep(0.0,.22,age)*(1.0-smoothstep(.92,1.42,age));
	if(gpu_summon_kind==2)return smoothstep(0.0,.10,age)*(1.0-smoothstep(.30,.68,age));
	return smoothstep(0.0,.10,age)*(1.0-smoothstep(.27,.70,age));
}

void gpu_mote_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,int mote_index,out float amount){
	bool cast=gpu_summon_kind==3;
	int sector=mote_index/(cast?4:8);
	int seed=mote_index%(cast?4:8);
	float offset=float(seed);
	float age=gpu_summon_time;
	float life=clamp((age-offset*.037)/1.1,0.0,1.0);
	float theta=float(sector)*3.14159265359/2.0+offset*.18+age*.9;
	float radius=(.40+offset*.065)*(1.0+life*.28);
	float height=.03+life*(.72+offset*.08);
	if(gpu_summon_kind==1){radius*=1.0-smoothstep(.24,1.3,age)*.8;height=.13+(1.0-life)*(.4+offset*.09);}
	if(cast){radius=.10+life*.20;height=(offset-1.5)*.055+sin(life*3.14159265359)*.15;}
	if(gpu_summon_kind==2){radius*=1.0+life*.45;height=.35+life*.45;}
	vec3 origin=vec3(cos(theta)*radius,height,sin(theta)*radius);
	float size=.35+float(seed%3)*.18;
	float yaw=3.14159265359/4.0-float(gpu_summon_camera_quadrant)*3.14159265359/2.0;
	float cy=cos(yaw),sy=sin(yaw),cx=cos(-3.14159265359/6.0),sx=sin(-3.14159265359/6.0);
	mat3 rotation=mat3(vec3(cy,0.0,-sy),vec3(sy*sx,cx,cy*sx),vec3(sy*cx,-sx,cy*cx));
	point=origin+rotation*point*size;
	normal=rotation*normal;
	tangent=rotation*tangent;
	binormal=rotation*binormal;
	amount=gpu_source_envelope(age)*(.55+float(seed%3)*.12);
}
