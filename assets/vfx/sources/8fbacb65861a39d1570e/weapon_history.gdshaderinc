uniform sampler2D gpu_weapon_history:filter_nearest,repeat_disable;
uniform int gpu_weapon_count=2;
void gpu_weapon_vertex(inout vec3 vertex,inout vec2 uv) {
 int index=min(gpu_weapon_count-1,int(vertex.x+.5));
 int edge=int(vertex.y+.5);
 vertex=texelFetch(gpu_weapon_history,ivec2(index,edge),0).xyz;
 uv=vec2(float(index)/float(max(1,gpu_weapon_count-1)),float(edge));
}
