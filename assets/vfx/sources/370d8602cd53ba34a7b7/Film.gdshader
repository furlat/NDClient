shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled;
uniform sampler2D flow_tex : repeat_enable, filter_linear;
uniform float clock = 0.0;
void fragment(){
 float phase = clock*3.14159265359;
 vec2 shift = vec2(cos(phase),sin(phase))*.24;
 float a = texture(flow_tex,UV*2.4+shift).r;
 float b = texture(flow_tex,UV*6.1-shift*.5).r;
 float stria = .5+.5*sin(UV.y*37.699112 + a*9.0-phase*2.0);
 float v = .13+.48*a+.23*pow(stria,3.0)+.12*b;
 ALBEDO = vec3(v); ALPHA = 1.0;
}
