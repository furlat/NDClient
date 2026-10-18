shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D vortex_tex : repeat_enable, filter_linear;
uniform float age=0.0;
uniform float strength=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.;float r=length(p);
 float a=atan(p.y,p.x)/6.2831853;
 float n=texture(noise_tex,vec2(a*4.+age*.21,r*1.8-age*.25)).r;
 float v=texture(vortex_tex,vec2(a*3.-age*.12,r*1.4)).r;
 float ridge=exp(-pow((r-.73)/.018,2.));
 float glow=exp(-pow((r-.73)/.075,2.));
 float arc=.38+.62*smoothstep(.12,.67,n);
 float rune=(1.-smoothstep(.20,.38,abs(fract(a*12.+age*.08)-.5)))*smoothstep(.52,.54,r)*(1.-smoothstep(.63,.65,r));
 float mist=smoothstep(.16,.52,v*n)*smoothstep(.12,.30,r)*(1.-smoothstep(.55,.78,r));
 float core=clamp(ridge*arc+rune*.65,0.,1.);
 ALBEDO=vec3(.34+core*.66);
 ALPHA=(core*.8+glow*arc*.23+mist*.12)*strength;
}
