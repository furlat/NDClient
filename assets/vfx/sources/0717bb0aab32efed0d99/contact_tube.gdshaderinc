uniform sampler2D gpu_tube_points : filter_nearest, repeat_disable;
instance uniform int gpu_tube_row = 0;
instance uniform int gpu_tube_count = 2;
instance uniform float gpu_tube_radius = .01;
instance uniform float gpu_tube_growth = 1.;
varying flat float gpu_tube_gate;
vec3 gpu_tube_point(int index){return texelFetch(gpu_tube_points,ivec2(index,gpu_tube_row),0).xyz;}
void gpu_tube_vertex(inout vec3 point,inout vec3 normal,out float gate){
	int index=int(point.x+.5); int corner=int(point.y+.5); float side=point.z;
	int count=max(2,int(ceil(float(gpu_tube_count)*clamp(gpu_tube_growth,.01,1.))));
	gate=index<count-1 ? 1. : 0.;
	int along=index+int(corner==2 || corner==4 || corner==5);
	float corner_side=float(corner==1 || corner==2 || corner==4);
	vec3 direction=gpu_tube_point(min(index+1,count-1))-gpu_tube_point(max(index-1,0));
	direction=length(direction)<.000001 ? vec3(0.,1.,0.) : normalize(direction);
	vec3 across=cross(direction,vec3(0.,0.,-1.));
	across=length(across)<.000001 ? vec3(1.,0.,0.) : normalize(across);
	vec3 around=normalize(cross(direction,across));
	float angle=6.28318530718*(side+corner_side)/7.;
	normal=across*cos(angle)+around*sin(angle);
	float taper=.25+.75*sin(3.14159265359*float(along)/float(count));
	point=gpu_tube_point(along)+normal*gpu_tube_radius*taper;
}
