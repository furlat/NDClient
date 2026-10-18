uniform sampler2D gpu_arcane_points:filter_nearest,repeat_disable;
instance uniform int gpu_arcane_count=2;
instance uniform int gpu_arcane_row=0;
instance uniform int gpu_arcane_sides=8;
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 int station=int(vertex.x+.5);float ring=vertex.y;
 vec4 data=texelFetch(gpu_arcane_points,ivec2(station,gpu_arcane_row),0);
 vec3 before=texelFetch(gpu_arcane_points,ivec2(max(0,station-1),gpu_arcane_row),0).xyz;
 vec3 after=texelFetch(gpu_arcane_points,ivec2(min(gpu_arcane_count-1,station+1),gpu_arcane_row),0).xyz;
 vec3 direction=normalize(after-before);
 vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.9 ? vec3(1.,0.,0.):vec3(0.,1.,0.);
 vec3 side=normalize(cross(direction,reference));
 vec3 across=normalize(cross(direction,side));
 float angle=ring/float(gpu_arcane_sides)*6.28318530718;
 normal=side*cos(angle)+across*sin(angle);
 vertex=data.xyz+normal*data.a;
}
