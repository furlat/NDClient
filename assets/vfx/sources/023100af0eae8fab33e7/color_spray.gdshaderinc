uniform vec3 gpu_color_caster;
uniform vec3 gpu_color_hand;
uniform vec3 gpu_color_direction=vec3(1.,0.,0.);
uniform vec3 gpu_color_across=vec3(0.,0.,1.);
uniform float gpu_color_range=3.;
vec3 gpu_color_point(vec2 uv,float gpu_layer_index) {
 vec3 point=gpu_color_caster+gpu_color_direction*uv.y*gpu_color_range+gpu_color_across*(uv.x-.5)*uv.y*gpu_color_range+(gpu_color_hand-gpu_color_caster)*(1.-uv.y);
 point.y+=sin(uv.x*3.14159265359)*sin(uv.y*3.14159265359)*gpu_layer_index*.165;
 return point;
}
void gpu_color_vertex(inout vec3 vertex,inout vec3 normal,vec2 uv,vec4 triangle) {
 float gpu_layer_index=vertex.z;
 vec3 a=gpu_color_point(uv,gpu_layer_index);
 vec3 b=gpu_color_point(triangle.xy,gpu_layer_index);
 vec3 c=gpu_color_point(triangle.zw,gpu_layer_index);
 vec3 face=cross(b-a,c-a);
 normal=length(face)>.000001 ? normalize(face):vec3(0.);
 vertex=a;
}
