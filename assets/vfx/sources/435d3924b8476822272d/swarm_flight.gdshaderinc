uniform sampler2D gpu_swarm_trajectory : filter_nearest, repeat_disable;
uniform float gpu_swarm_seconds=0.;
uniform bool gpu_swarm_seed=false;
uniform float gpu_swarm_wing_sign=0.;
uniform mat4 gpu_swarm_before=mat4(1.);
uniform mat4 gpu_swarm_after=mat4(1.);
varying flat float gpu_swarm_visible;
vec3 gpu_swarm_track(int index,int frame){return texelFetch(gpu_swarm_trajectory,ivec2(frame,index),0).xyz;}
vec3 gpu_swarm_loop(int index,float seconds){
	float local=mod(seconds+float(index%8)*.75,6.);
	vec3 point;
	if(local<4.){
		float sample_frame=local*144.;int frame=min(int(sample_frame),575);
		point=mix(gpu_swarm_track(index,frame),gpu_swarm_track(index,frame+1),sample_frame-float(frame));
	}else{
		float u=(local-4.)/2.;float square=u*u;float cube=square*u;
		vec3 start=gpu_swarm_track(index,576);vec3 end=gpu_swarm_track(index,0);
		vec3 start_velocity=(start-gpu_swarm_track(index,575))*144.;
		vec3 end_velocity=(gpu_swarm_track(index,1)-end)*144.;
		point=(2.*cube-3.*square+1.)*start+(cube-2.*square+u)*2.*start_velocity+(-2.*cube+3.*square)*end+(cube-square)*2.*end_velocity;
	}
	float radius=length(point.xz);
	if(radius>3.65)point.xz*=(3.65+.20*(1.-exp(-(radius-3.65)/.20)))/radius;
	if(point.y<.3)point.y=.3-.18*(1.-exp(-(.3-point.y)/.18));
	if(point.y>2.4)point.y=2.4+.2*(1.-exp(-(point.y-2.4)/.2));
	return point;
}
vec3 gpu_swarm_site(int index){
	int site=index%7;
	if(site==0)return vec3(-1.6,.12,-.7);
	if(site==1)return vec3(.8,.12,-1.3);
	if(site==2)return vec3(-.4,.12,.6);
	if(site==3)return vec3(1.3,.12,.9);
	if(site==4)return vec3(-1.8,.12,1.);
	if(site==5)return vec3(.1,.12,-.2);
	return vec3(.4,.12,1.8);
}
vec3 gpu_swarm_position(int index,float seconds){
	float number=float(index);float delay=float(index%13)*.035;
	vec3 seed=gpu_swarm_site(index)+vec3(sin(number*1.73)*.16,0.,cos(number*2.31)*.16);
	return mix(seed,gpu_swarm_loop(index,seconds-2.),smoothstep(delay,1.85,seconds));
}
mat3 gpu_swarm_roll(float angle){
	float c=cos(angle);float s=sin(angle);
	return mat3(vec3(c,s,0.),vec3(-s,c,0.),vec3(0.,0.,1.));
}
void gpu_swarm_vertex(inout vec3 point,inout vec3 normal,int locust_index,out float gate){
	float seconds=gpu_swarm_seconds;float number=float(locust_index);
	gate=1.;
	if(gpu_swarm_seed){
		float age=seconds-float(locust_index%24)*.035;
		float angle=float(locust_index%7)*6.28318530718/7.+age*3.;
		float scale=max(.001,sin(clamp(age/.48,0.,1.)*3.14159265359));
		point=point*scale+gpu_swarm_site(locust_index)+vec3(cos(angle)*age*.4,age*.9,sin(angle)*age*.4);
		gate=age>0. && age<.48 ? 1. : 0.;
		return;
	}
	vec3 centre=gpu_swarm_position(locust_index,seconds);
	vec3 before=gpu_swarm_position(locust_index,seconds-.004);
	vec3 after=gpu_swarm_position(locust_index,seconds+.004);
	vec3 velocity=(after-before)/.008;
	vec3 backward=-normalize(velocity);
	vec3 across=normalize(cross(vec3(0.,1.,0.),backward));
	vec3 up=normalize(cross(backward,across));
	mat3 heading=mat3(across,up,backward);
	float turn=cross(normalize(centre-before),normalize(after-centre)).y;
	heading*=gpu_swarm_roll(-clamp(turn*20.,-.55,.55));
	float size=.085+.03*(.5+.5*sin(number*7.17));
	if(locust_index%17==0)size=.14;
	size*=max(.001,smoothstep(float(locust_index%13)*.035,float(locust_index%13)*.035+.22,seconds));
	float flutter=sin(6.28318530718*round(float(154+locust_index%19)*.75)*(seconds-2.)/6.+number*1.79)*.65;
	mat4 wing=mat4(gpu_swarm_roll(flutter*gpu_swarm_wing_sign));
	mat4 local=gpu_swarm_before*wing*gpu_swarm_after;
	point=centre+heading*(local*vec4(point,1.)).xyz*size;
	normal=normalize(heading*transpose(inverse(mat3(local)))*normal);
}
