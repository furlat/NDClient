shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_noise : repeat_enable, filter_linear;
uniform float clock=0.;
uniform float shell=0.;
uniform bool wake=false;
void vertex(){
 float age=clock-shell*.105;
 float u=clamp(age/.72,0.,1.);
 float a=UV.x*6.2831853;
 float r=.065+.50*u;
 // Irregular sound fronts, not a ground sheet or a regular cone cage.
 r*=1.+.055*sin(a*3.+shell*1.7)+.032*sin(a*7.-age*4.);
 // Curved caps retain a crescent profile when the ring plane is edge-on.
 float radial=wake?mix(.42,1.,UV.y):mix(.85,1.,UV.y);
 float bow=.62*r*sqrt(max(0.,1.-radial*radial));
 float z=.08+2.22*u+bow-.30*r+.035*sin(a*4.+shell)*u;
 r*=radial;
 VERTEX=vec3(cos(a)*r,sin(a)*r*.82,z);
}
void fragment(){
 float age=clock-shell*.105;
 float a=UV.x*6.2831853;
 float noise=texture(source_noise,vec2(UV.x*5.+shell*.13,UV.y*.4-age*.48)).r;
 float broken=smoothstep(.22,.47,noise+.10*sin(a*5.+shell));
 float rim=pow(sin(UV.y*3.14159265),wake?1.5:2.);
 float onset=smoothstep(0.,.06,age);
 float retire=1.-smoothstep(.67,.91,age);
 float emphasis=.62+.30*sin(a)*sin(a);
 ALBEDO=vec3(wake?.25+.17*noise:.53+.30*noise);
 ALPHA=rim*broken*onset*retire*emphasis*(wake?.35:.94)*(1.-shell*.14);
}
