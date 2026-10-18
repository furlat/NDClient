shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float clock=0.;
uniform bool impact=false;
uniform sampler2D impact_tex : filter_linear;
void fragment(){
 if(impact){
  float a=texture(impact_tex,UV).r;
  float edge=smoothstep(0.,.09,UV.x)*(1.-smoothstep(.91,1.,UV.x))*smoothstep(0.,.09,UV.y)*(1.-smoothstep(.91,1.,UV.y));
  ALBEDO=vec3(.3+.5*a);
  ALPHA=a*edge*(1.-smoothstep(.09,.39,clock))*.9;
 }else{
  float edge=sin(UV.y*3.14159265);
  float ridge=pow(edge,6.);
  float etch=.65+.35*sin(UV.x*48.+UV.y*14.);
  ALBEDO=vec3(.25+.60*ridge);
  ALPHA=edge*UV.x*etch*(1.-smoothstep(.67,.94,clock))*.92;
 }
}
