shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength=0.0;
uniform float side=0.0;
uniform vec2 camera_ground=vec2(.70710678,.70710678);
varying vec3 world_p;
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float d=dot(world_p.xz,camera_ground);
 if(side<-.5&&d>=0.)discard;if(side>.5&&d<0.)discard;
 vec2 p=(UV-.5)*2.;float r=length(p);float halo=1.-smoothstep(.18,1.,r);float core=1.-smoothstep(.05,.28,r);
 ALBEDO=vec3(.22+.68*core+.08*halo);
 ALPHA=(core*.72+halo*.26)*strength;
}
