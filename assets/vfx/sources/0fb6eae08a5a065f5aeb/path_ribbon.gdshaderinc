uniform sampler2D gpu_path_points : filter_nearest, repeat_disable;
instance uniform int gpu_path_count = 2;
instance uniform int gpu_path_row = 0;
void gpu_path_station(int index,out vec3 point,out float width) {
	vec4 data=texelFetch(gpu_path_points,ivec2(index,gpu_path_row),0);
	point=data.xyz; width=data.a;
}
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	int station=int(point.x+.5); float edge=point.y; float fin=point.z;
	vec3 centre; vec3 before; vec3 after; float width; float ignored;
	gpu_path_station(station,centre,width);
	gpu_path_station(max(0,station-1),before,ignored);
	gpu_path_station(min(gpu_path_count-1,station+1),after,ignored);
	vec3 direction=length(after-before)<.000001 ? vec3(0.,0.,-1.) : normalize(after-before);
	vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.99 ? vec3(1.,0.,0.) : vec3(0.,1.,0.);
	vec3 base=normalize(cross(direction,reference));
	float angle=fin*6.28318530718/3.;
	vec3 side=base*cos(angle)+cross(direction,base)*sin(angle)+direction*dot(direction,base)*(1.-cos(angle));
	point=centre+side*width*edge;
	normal=normalize(cross(side,direction));
}
