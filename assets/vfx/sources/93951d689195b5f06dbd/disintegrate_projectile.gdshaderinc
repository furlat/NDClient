uniform vec3 gpu_ray_start = vec3(0.0);
uniform vec3 gpu_ray_end = vec3(0.0,0.0,1.0);
uniform float gpu_ray_head = 0.0;
uniform float gpu_ray_width = 1.0;
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
	float phase=point.x/16.0;
	float edge=point.y;
	float angle=point.z*3.14159265359/3.0;
	vec3 displacement=gpu_ray_end-gpu_ray_start;
	vec3 direction=length(displacement)>.000001?normalize(displacement):vec3(0.0);
	vec3 right=cross(direction,vec3(0.0,1.0,0.0));
	right=length(right)>.000001?normalize(right):vec3(1.0,0.0,0.0);
	vec3 up=cross(right,direction);
	up=length(up)>.000001?normalize(up):vec3(0.0);
	vec3 across=right*cos(angle)+up*sin(angle);
	float tail=max(0.0,gpu_ray_head-.70);
	float along=mix(tail,gpu_ray_head,phase);
	float width=.52*gpu_ray_width*pow(phase,.65)*pow(max(0.0,1.0-phase),.25)*min(1.0,gpu_ray_head/.14);
	point=mix(gpu_ray_start,gpu_ray_end,along)+across*width*edge;
	// The original ray mesh has no normal/tangent arrays; retain native defaults.
	normal=vec3(0.0,0.0,1.0);
	tangent=vec3(1.0,0.0,0.0);
	binormal=vec3(0.0,1.0,0.0);
}
