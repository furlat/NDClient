#include "res://assets/vfx/sources/b9fa87f63d2dcea15886/support_paths.gdshaderinc"
instance uniform int gpu_vine_index=0;
uniform float gpu_vine_left=0.;
uniform float gpu_vine_right=0.;
uniform float gpu_vine_height=0.;

vec3 gpu_vine_point(int station){
 float u=float(station)/29.;
 float horizontal=gpu_vine_index==1 ? mix(.88,.12,u) : mix(.12,.88,u);
 float low=gpu_vine_index==0 ? .17 : (gpu_vine_index==1 ? .33 : .49);
 vec3 desired=gpu_support_side*mix(gpu_vine_left,gpu_vine_right,horizontal);
 desired.y=gpu_vine_height*(low+.10*sin(u*3.14159265359)+.09*u);
 vec3 closest=vec3(0.0);vec3 normal=gpu_support_normal;float best=1e30;
 for(int index=0;index<gpu_support_count;index++){
  vec3 candidate=texelFetch(gpu_support_points,ivec2(index,0),0).xyz;
  float distance=dot(candidate-desired,candidate-desired);
  if(distance<best){best=distance;closest=candidate;normal=texelFetch(gpu_support_points,ivec2(index,1),0).xyz;}
 }
 return closest+normalize(normal)*.018;
}

void gpu_vine_vertex(inout vec3 vertex,inout vec3 normal){
 int index=int(vertex.x+.5);int corner=int(vertex.y+.5);float side=vertex.z;
 int along=index+int(corner==2 || corner==4 || corner==5);
 float corner_side=float(corner==1 || corner==2 || corner==4);
 vec3 tangent=gpu_vine_point(min(index+1,29))-gpu_vine_point(max(index-1,0));
 tangent=length(tangent)<.000001 ? vec3(0.,1.,0.) : normalize(tangent);
 vec3 across=cross(tangent,vec3(0.,0.,-1.));
 across=length(across)<.000001 ? vec3(1.,0.,0.) : normalize(across);
 vec3 around=normalize(cross(tangent,across));
 float angle=6.28318530718*(side+corner_side)/7.;
 normal=across*cos(angle)+around*sin(angle);
 float taper=.25+.75*sin(3.14159265359*float(along)/30.);
 vertex=gpu_vine_point(along)+normal*.013*taper;
}
