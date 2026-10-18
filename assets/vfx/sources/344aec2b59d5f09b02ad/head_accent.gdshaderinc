uniform int gpu_head_shape=0;
uniform int gpu_head_mode=0;
uniform float gpu_head_seconds=0.;
uniform float gpu_head_width=.025;
uniform float gpu_head_intensity=1.;
uniform vec3 gpu_head_heading;
uniform vec3 gpu_head_side;
uniform vec3 gpu_head_left;
uniform vec3 gpu_head_right;
uniform vec3 gpu_head_left_normal;
uniform vec3 gpu_head_right_normal;
uniform vec3 gpu_head_hand;
instance uniform int gpu_head_number=0;
instance uniform int gpu_head_layer=0;
vec3 gpu_head_point(int station) {
 float u=float(station)/32.;float t=gpu_head_seconds;float number=float(gpu_head_number);
 float sign_value=gpu_head_number%2==0 ? -1.:1.;
 vec3 normal=sign_value<0.?gpu_head_left_normal:gpu_head_right_normal;
 vec3 anchor=sign_value<0.?gpu_head_left:gpu_head_right;
 if(gpu_head_mode==1)anchor=gpu_head_hand+gpu_head_heading*.055;
 vec3 point;
 if(gpu_head_shape==0){
  float pulse=sin(t*3.-u*6.28318530718+number);
  point=anchor+gpu_head_side*sign_value*(.028+.018*sin(u*3.14159265359)+.008*pulse);
  point+=gpu_head_heading*((u-.5)*.17+float(gpu_head_number/2)*.026);
  point+=vec3(0.,.038*sin(u*6.28318530718+.35*sign_value)+.006*pulse,0.);
  point+=normal*(.012*sin(u*3.14159265359)+.006*sin(t*2.+u*3.14159265359+number));
 }else{
  float angle=mix(-1.2,1.2,u)+.12*sin(t*3.+number);
  float r=.11+float(gpu_head_number/2)*.045;
  point=anchor+gpu_head_side*sign_value*(.025+r*(1.-cos(angle)));
  point+=vec3(0.,sin(angle)*r,0.)+gpu_head_heading*(.05*sin(u*3.14159265359+t*1.4+number));
 }
 if(gpu_head_mode==1)point=anchor+gpu_head_heading*(u*.16)+gpu_head_side*((u-.5)*.06)+vec3(0.,.035*sin(u*3.14159265359+number),0.);
 else if(gpu_head_mode==2)point+=normal*(.10*smoothstep(0.,.3,t));
 return point;
}
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 int station=int(vertex.x+.5);float edge=vertex.y;float fin=vertex.z;
 vec3 before=gpu_head_point(max(0,station-1));vec3 after=gpu_head_point(min(32,station+1));
 vec3 direction=length(after-before)>.000001?normalize(after-before):vec3(0.,0.,-1.);
 vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.99?vec3(1.,0.,0.):vec3(0.,1.,0.);
 vec3 base=normalize(cross(direction,reference));float angle=fin*6.28318530718/3.;
 vec3 side=base*cos(angle)+cross(direction,base)*sin(angle)+direction*dot(direction,base)*(1.-cos(angle));
 float u=float(station)/32.;
 float width=gpu_head_width*pow(max(0.,sin(u*3.14159265359)),.75)*gpu_head_intensity*(1.+.12*sin(gpu_head_seconds*4.-u*6.28318530718+float(gpu_head_number)))*(1.+float(gpu_head_layer)*.25);
 vertex=gpu_head_point(station)+side*width*edge;normal=normalize(cross(side,direction));
}
