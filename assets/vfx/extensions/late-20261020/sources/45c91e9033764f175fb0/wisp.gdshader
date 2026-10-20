shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float age=0.0;
uniform float strength=0.0;
uniform float seed=0.0;
uniform float side=0.0;
uniform vec2 camera_ground=vec2(.70710678,.70710678);
varying vec3 world_p;
void vertex(){world_p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float depth=dot(world_p.xz,camera_ground);
 if(side<-.5 && depth>=0.)discard;
 if(side>.5 && depth<0.)discard;
 float n=texture(noise_tex,vec2(UV.x*2.-age*.5+seed,UV.y*.65+seed)).r;
 float edge=sin(clamp(UV.y,0.,1.)*3.14159265);
 float taper=pow(sin(clamp(UV.x,0.,1.)*3.14159265),.72);
 float grain=smoothstep(.18,.73,n);
 float core=pow(edge,3.)*(.45+.55*grain)*taper;
 ALBEDO=vec3(.40+.60*core);
 ALPHA=smoothstep(.04,.35,core)*strength*(.50+.47*grain);
}
