uniform int gpu_gust_piece = 0;
uniform float gpu_gust_time = 0.0;
uniform float gpu_gust_reach = 0.0;
uniform vec3 gpu_gust_hand = vec3(0.0);
uniform vec3 gpu_gust_direction = vec3(1.0,0.0,0.0);
uniform vec3 gpu_gust_across = vec3(0.0,0.0,1.0);
vec3 gpu_gust_point(float station,float edge) {
	float u=station/64.0;
	float which=float(gpu_gust_piece);
	float lengths[3]={13.0,9.3,6.2};
	float widths[3]={1.15,.83,.61};
	float offsets[3]={-.85,.75,.15};
	float start=mix(max(0.0,gpu_gust_reach-lengths[gpu_gust_piece]),0.0,smoothstep(1.3,1.7,gpu_gust_time));
	float along=mix(start,gpu_gust_reach,u);
	float off=offsets[gpu_gust_piece]+.38*sin(u*8.0-gpu_gust_time*2.3+which*2.0)+.15*sin(u*17.0-gpu_gust_time*3.1);
	float height=.8+which*.30+.38*sin(u*8.0-gpu_gust_time*2.5+which);
	float width=widths[gpu_gust_piece]*pow(max(0.0,sin(3.14159265359*u)),.7)*(.72+.28*sin(u*19.0-gpu_gust_time*4.0+which));
	float roll=.8+.45*sin(u*9.0-gpu_gust_time*1.3+which);
	vec3 axis=gpu_gust_across*cos(roll)+vec3(0.0,1.0,0.0)*sin(roll);
	float blend=1.0-smoothstep(0.0,4.0,along);
	return gpu_gust_direction*along+(vec3(gpu_gust_hand.x,0.0,gpu_gust_hand.z)+vec3(0.0,gpu_gust_hand.y-height,0.0))*blend+gpu_gust_across*off*(1.0-blend)+vec3(0.0,height,0.0)+axis*width*edge;
}
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	float station=point.x;
	float edge=point.y;
	vec3 previous=gpu_gust_point(max(0.0,station-1.0),0.0);
	vec3 following=gpu_gust_point(min(64.0,station+1.0),0.0);
	vec3 along=following-previous;
	along=length(along)>.000001?normalize(along):vec3(0.0);
	vec3 across=gpu_gust_point(station,1.0)-gpu_gust_point(station,-1.0);
	across=length(across)>.000001?normalize(across):vec3(1.0,0.0,0.0);
	normal=cross(across,along);
	normal=length(normal)>.000001?normalize(normal):vec3(0.0,1.0,0.0);
	tangent=across;
	binormal=normalize(cross(normal,tangent));
	point=gpu_gust_point(station,edge);
}
