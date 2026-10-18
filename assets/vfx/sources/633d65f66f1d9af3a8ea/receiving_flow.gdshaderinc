uniform sampler2D gpu_flow_support : filter_nearest, repeat_disable;
uniform int gpu_flow_curve = 0;
uniform bool gpu_flow_petal = false;
uniform vec3 gpu_flow_side = vec3(1.0,0.0,0.0);
uniform float gpu_flow_phase = 0.0;
uniform float gpu_flow_width = .03;

vec3 gpu_flow_support_point(int station) {
	float u=float(station)/12.0;
	vec3 base=texelFetch(gpu_flow_support,ivec2(station,gpu_flow_curve*2),0).xyz;
	vec3 normal=texelFetch(gpu_flow_support,ivec2(station,gpu_flow_curve*2+1),0).xyz;
	return base+normal*(.015*sin(body_flow_clock*1.65+u*6.28318530718+gpu_flow_phase))+gpu_flow_side*(.012*sin(body_flow_clock*1.15+u*3.14159265359+gpu_flow_phase));
}

vec3 gpu_flow_point(int station) {
	float at=float(station)*.25;
	int index=min(int(at),11);
	float weight=at-float(index);
	vec3 a=gpu_flow_support_point(max(index-1,0));
	vec3 b=gpu_flow_support_point(index);
	vec3 c=gpu_flow_support_point(index+1);
	vec3 d=gpu_flow_support_point(min(index+2,12));
	return .5*((b*2.0)+(-a+c)*weight+(a*2.0-b*5.0+c*4.0-d)*weight*weight+(-a+b*3.0-c*3.0+d)*weight*weight*weight);
}

vec3 gpu_flow_receiving_normal(int station) {
	float at=float(station)*.25;
	int index=min(int(at),11);
	float weight=at-float(index);
	vec3 a=texelFetch(gpu_flow_support,ivec2(index,gpu_flow_curve*2+1),0).xyz;
	vec3 b=texelFetch(gpu_flow_support,ivec2(index+1,gpu_flow_curve*2+1),0).xyz;
	vec3 axis=cross(a,b);
	float axis_length=length(axis);
	if(axis_length<.000001)return normalize(mix(a,b,weight));
	axis/=axis_length;
	float angle=atan(axis_length,dot(a,b))*weight;
	return normalize(a*cos(angle)+cross(axis,a)*sin(angle)+axis*dot(axis,a)*(1.0-cos(angle)));
}

void gpu_flow_deform(inout vec3 vertex,inout vec3 normal,inout vec4 colour) {
	int station=int(vertex.x+.5);
	float edge=vertex.y;
	float fin=vertex.z;
	float u=float(station)/48.0;
	vec3 point=gpu_flow_point(station);
	vec3 tangent=gpu_flow_point(min(station+1,48))-gpu_flow_point(max(station-1,0));
	tangent=length(tangent)>.000001?normalize(tangent):vec3(0.0,0.0,-1.0);
	vec3 side;
	if(gpu_flow_petal) {
		side=cross(tangent,gpu_flow_receiving_normal(station));
		side=length(side)>.000001?normalize(side):gpu_flow_side;
	} else {
		vec3 reference=abs(dot(tangent,vec3(0.0,1.0,0.0)))>.99?vec3(1.0,0.0,0.0):vec3(0.0,1.0,0.0);
		vec3 axis=normalize(cross(tangent,reference));
		float angle=fin*6.28318530718/3.0;
		side=axis*cos(angle)+cross(tangent,axis)*sin(angle)+tangent*dot(tangent,axis)*(1.0-cos(angle));
	}
	normal=normalize(cross(side,tangent));
	float pulse=.72+.28*sin(u*6.28318530718-body_flow_clock*3.1+gpu_flow_phase);
	float width=gpu_flow_width*pow(max(0.0,sin(3.14159265359*u)),.8)*pulse;
	vertex=point+side*width*edge;
	if(gpu_flow_petal)vertex+=normal*(1.0-abs(edge))*.018*sin(3.14159265359*u);
}
