uniform sampler2D gpu_cambered_points : filter_nearest, repeat_disable;
instance uniform int gpu_cambered_row=0;
instance uniform int gpu_cambered_count=2;
uniform vec3 gpu_cambered_fallback=vec3(1.,0.,0.);
void gpu_cambered_station(int station,out vec3 point,out vec3 normal,out float width){
	vec4 value=texelFetch(gpu_cambered_points,ivec2(station,gpu_cambered_row*2),0);
	point=value.xyz; width=value.a;
	normal=texelFetch(gpu_cambered_points,ivec2(station,gpu_cambered_row*2+1),0).xyz;
}
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal){
	int station=int(point.x+.5);float edge=point.y;
	vec3 centre;vec3 before;vec3 after;vec3 ignored;float width;float ignored_width;
	gpu_cambered_station(station,centre,normal,width);
	gpu_cambered_station(max(0,station-1),before,ignored,ignored_width);
	gpu_cambered_station(min(gpu_cambered_count-1,station+1),after,ignored,ignored_width);
	vec3 direction=normalize(after-before);
	vec3 across=cross(normal,direction);
	across=length(across)<.000001 ? gpu_cambered_fallback : normalize(across);
	width*=pow(max(0.,sin(float(station)/float(gpu_cambered_count-1)*3.14159265359)),.65);
	point=centre+across*edge*width+normal*(1.-edge*edge)*width*.18;
}
