#include "res://assets/vfx/sources/b9fa87f63d2dcea15886/support_paths.gdshaderinc"
uniform int gpu_divine_profile=0;

vec2 gpu_divine_polyline(float u,vec2 a,vec2 b,vec2 c){
 return u<.5 ? mix(a,b,u*2.0) : mix(b,c,(u-.5)*2.0);
}

void gpu_divine_station(float u,int piece,out vec3 point,out vec3 normal,out float width){
 vec3 up=gpu_support_up;vec3 side=gpu_support_side;normal=gpu_support_normal;
 vec3 centre=gpu_support_centre+normal*.04;
 float parity=piece%2==0 ? -1.0 : 1.0;
 width=.012;
 if(gpu_divine_profile==0){
  centre=vec3(centre.x,gpu_support_bottom+gpu_support_height+.17,centre.z)-normal*.005;
  if(piece<2){
   float angle=float(piece)*3.14159265359+.24+u*(3.14159265359-.48);
   point=centre+side*cos(angle)*.105+up*sin(angle)*.105;width=.014;
  }else{
   parity=piece==2 ? -1.0 : 1.0;
   vec2 offset=gpu_divine_polyline(u,vec2(parity*.025,-.012),vec2(parity*.080,-.045),vec2(parity*.025,-.080));
   point=centre+side*offset.x+up*offset.y;width=.013;
  }
 }else if(gpu_divine_profile==1){
  centre=vec3(centre.x,gpu_support_bottom+gpu_support_height-.025,centre.z);
  if(piece<2){point=centre+side*(u-.5)*.18+up*parity*sin(u*3.14159265359)*.042;width=.011;}
  else {point=centre+up*(u<.5 ? mix(-.028,.028,u*2.0) : mix(.028,.085,(u-.5)*2.0));width=.009;}
 }else if(gpu_divine_profile==2){
  centre.y=gpu_support_bottom+gpu_support_height*.13;
  float rise=float(piece)*.035;
  vec2 offset=gpu_divine_polyline(u,vec2(-.075,rise),vec2(0.0,-.04+rise),vec2(.075,rise));
  point=centre+side*offset.x+up*offset.y;
 }else if(gpu_divine_profile==3){
  vec2 offsets[5]={vec2(-.065,-.045),vec2(-.055,.035),vec2(0.,.065),vec2(.055,.035),vec2(.065,-.045)};
  float segment=u*4.;int index=min(3,int(segment));vec2 offset=mix(offsets[index],offsets[index+1],segment-float(index));
  centre=gpu_support_centre+up*gpu_support_height*.19;
  float across=gpu_support_half_width*.48+offset.x;
  gpu_support(dot(centre-gpu_support_centre,side)+across,centre.y+offset.y,point,normal);
  point+=side*(across-dot(point-centre,side))+up*(offset.y-dot(point-centre,up))+normal*.055;width=.016;
 }else if(gpu_divine_profile==4){
  centre.y=gpu_support_bottom+gpu_support_height*.47;
  vec2 offset=gpu_divine_polyline(u,vec2(-.065,-.04),vec2(0.,.055),vec2(.065,-.04));
  point=centre+side*offset.x+up*offset.y;width=.014;
 }else{
  float tier=floor(float(piece)/2.);float wave=sin(u*3.14159265359);
  gpu_support(parity*gpu_support_half_width*(.62+.18*wave+.12*tier),gpu_support_bottom+gpu_support_height*(.33+.30*u+.075*tier),point,normal);
  point+=normal*(.045+.07*wave)+side*parity*.065*wave;width=.085-.012*tier;
 }
}

void gpu_divine_vertex(inout vec3 vertex,inout vec3 normal){
 float u=vertex.x;float edge=vertex.y;int piece=int(vertex.z+.5);
 vec3 centre;vec3 before;vec3 after;vec3 ignored;float width;float ignored_width;
 gpu_divine_station(u,piece,centre,normal,width);
 gpu_divine_station(max(0.,u-1./24.),piece,before,ignored,ignored_width);
 gpu_divine_station(min(1.,u+1./24.),piece,after,ignored,ignored_width);
 vec3 across=cross(normal,after-before);
 across=length(across)<.000001 ? gpu_support_side : normalize(across);
 width*=pow(max(0.,sin(u*3.14159265359)),.65);
 vertex=centre+across*edge*width+normal*(1.-edge*edge)*width*.18;
}
