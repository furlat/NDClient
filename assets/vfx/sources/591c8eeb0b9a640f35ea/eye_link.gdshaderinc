uniform vec3 gpu_eye_start;
uniform vec3 gpu_eye_recipient;
uniform vec3 gpu_eye_across;
uniform float gpu_eye_width=.1;
uniform float gpu_eye_arc=.2;
void gpu_directed_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 float u=point.x/128.;float edge=point.y;
 point=mix(gpu_eye_start,gpu_eye_recipient,u)+vec3(0.,sin(u*3.14159265359)*gpu_eye_arc,0.)+gpu_eye_across*edge*gpu_eye_width;
}
