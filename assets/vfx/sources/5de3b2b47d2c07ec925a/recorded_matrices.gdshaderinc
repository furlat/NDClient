uniform sampler2D gpu_recorded_matrices : filter_nearest, repeat_disable;
uniform float gpu_recorded_frame=0.;
varying flat float gpu_recorded_visible;
void gpu_recorded_vertex(inout vec3 point,inout vec3 normal,int mesh_index,out float gate){
	int frame=int(gpu_recorded_frame+.5);
	vec4 a=texelFetch(gpu_recorded_matrices,ivec2(frame,mesh_index*3),0);
	vec4 b=texelFetch(gpu_recorded_matrices,ivec2(frame,mesh_index*3+1),0);
	vec4 c=texelFetch(gpu_recorded_matrices,ivec2(frame,mesh_index*3+2),0);
	mat3 basis=mat3(vec3(a.x,b.x,c.x),vec3(a.y,b.y,c.y),vec3(a.z,b.z,c.z));
	point=basis*point+vec3(a.w,b.w,c.w);
	gate=abs(determinant(basis))>.00000000000000001 ? 1. : 0.;
	normal=gate>.5 ? normalize(transpose(inverse(basis))*normal) : vec3(0.,1.,0.);
}
