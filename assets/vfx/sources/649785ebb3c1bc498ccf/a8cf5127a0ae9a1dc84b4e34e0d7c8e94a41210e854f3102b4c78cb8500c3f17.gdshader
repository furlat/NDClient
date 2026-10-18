shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_noise : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float side = 0.0;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float dep=wp.x+wp.z;
 if((side<-.5 && dep>=0.) || (side>.5 && dep<0.)) discard;
 float n=texture(source_noise,UV*vec2(5.,.8)+vec2(-clock*.48,seed)).r;
 float stria=.5+.5*sin(UV.x*75.398-clock*12.+n*4.+seed*6.);
 float edge=pow(max(0.,1.-abs(UV.y-.5)*2.),1.4);
 float taper=smoothstep(0.,.055,UV.x)*(1.-smoothstep(.91,1.,UV.x));
 float core=pow(stria,2.);
 ALBEDO=vec3(.19+.55*core+.15*n);
 ALPHA=edge*taper*strength*(.45+.55*n)*(.5+.5*stria);
}
