uniform float gpu_blade_seconds=0.;
uniform float gpu_blade_spin=1.;
uniform float gpu_blade_height=4.;
uniform float gpu_blade_length=1.;
uniform vec3 gpu_blade_from;
uniform vec3 gpu_blade_to;
instance uniform vec3 gpu_blade_station;
vec3 gpu_blade_tip(float time) {
 vec3 direction=normalize(gpu_blade_to-gpu_blade_from);
 vec3 cross_direction=normalize(cross(direction,vec3(0.,1.,0.)));
 float phase=time*gpu_blade_spin+gpu_blade_station.z;
 vec3 centre=mix(gpu_blade_from,gpu_blade_to,gpu_blade_station.x)+vec3(0.,gpu_blade_station.y,0.);
 centre+=cross_direction*.18*cos(phase*.7+gpu_blade_station.z);
 vec3 axis=normalize(direction*cos(phase)+vec3(0.,1.,0.)*sin(phase)+cross_direction*.25*sin(phase*.7));
 float along=min(gpu_blade_station.x,1.-gpu_blade_station.x)*length(gpu_blade_to-gpu_blade_from);
 float height=min(gpu_blade_station.y,gpu_blade_height-gpu_blade_station.y);
 float half_length=gpu_blade_length*.5;
 float scale=min(1.,max(.01,min(along,height)-.035)/half_length);
 return centre+axis*half_length*scale;
}
vec3 gpu_blade_station_point(int index) {return gpu_blade_tip(gpu_blade_seconds-.16*(1.-float(index)/11.));}
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 int index=int(vertex.x+.5);float edge=vertex.y;float fin=vertex.z;
 vec3 before=gpu_blade_station_point(max(0,index-1));
 vec3 after=gpu_blade_station_point(min(11,index+1));
 vec3 direction=length(after-before)>.000001?normalize(after-before):vec3(0.,0.,-1.);
 vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.99 ? vec3(1.,0.,0.):vec3(0.,1.,0.);
 vec3 base=normalize(cross(direction,reference));
 float angle=fin*6.28318530718/3.;
 vec3 side=base*cos(angle)+cross(direction,base)*sin(angle)+direction*dot(direction,base)*(1.-cos(angle));
 vertex=gpu_blade_station_point(index)+side*.028*sin(float(index)/11.*3.14159265359)*edge;
 normal=normalize(cross(side,direction));
}
