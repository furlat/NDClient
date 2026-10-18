uniform int gpu_prism_kind=0;
uniform int gpu_prism_index=0;
uniform int gpu_prism_count=25;
uniform float gpu_prism_width=.1;
uniform float gpu_prism_length=12.;
uniform mat4 gpu_prism_inverse;
uniform vec3 gpu_prism_source;
uniform vec3 gpu_prism_ground;
uniform vec3 gpu_prism_direction;
uniform vec3 gpu_prism_side;
vec3 gpu_prism_point(int station) {
 float u=float(station)/float(gpu_prism_count-1);
 float index=float(gpu_prism_index);
 vec3 world;
 if(gpu_prism_kind==0) {
  float sector=(index+.5)/21.-.5;
  float distance=u*gpu_prism_length;
  float drift=sin(u*3.14159265359)*sin(index*1.7+u*3.)*distance*.008;
  world=gpu_prism_ground+gpu_prism_direction*distance+gpu_prism_side*(sector*distance+drift)+(gpu_prism_source-gpu_prism_ground)*(1.-u);
  world.y=mix(gpu_prism_source.y,gpu_prism_ground.y+.16+float(gpu_prism_index%3)*.32,u)+sin(u*3.14159265359)*float(gpu_prism_index%3)*.22;
 } else {
  vec3 local=gpu_prism_side*(u-.5)*.58+vec3(0.,sin(u*3.14159265359)*.28+float(gpu_prism_index%2)*.18-.09,0.);
  world=gpu_prism_source+local+gpu_prism_direction*(float(gpu_prism_index%2)-.5)*.16;
 }
 return (gpu_prism_inverse*vec4(world,1.)).xyz;
}
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 int station=int(vertex.x+.5); float edge=vertex.y*.5;
 vec3 before=gpu_prism_point(max(0,station-1));
 vec3 after=gpu_prism_point(min(gpu_prism_count-1,station+1));
 vec3 direction=length(after-before)>.000001 ? normalize(after-before):vec3(0.);
 normal=gpu_prism_kind==1 ? gpu_prism_direction : (gpu_prism_index%2==0 ? vec3(0.,1.,0.):gpu_prism_side);
 vec3 across=cross(direction,normal);
 across=length(across)>.000001 ? normalize(across):vec3(1.,0.,0.);
 float u=float(station)/float(gpu_prism_count-1);
 vertex=gpu_prism_point(station)+across*gpu_prism_width*sin(u*3.14159265359)*edge;
}
