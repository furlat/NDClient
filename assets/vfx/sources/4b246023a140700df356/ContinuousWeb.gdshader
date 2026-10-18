shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D silk_texture:source_color,filter_linear;
uniform float source_clock=0.;
uniform vec2 forward_axis=vec2(1.,0.);
void vertex(){
 vec2 q=VERTEX.xz;float radius=length(q);float edge=max(abs(q.x),abs(q.y));
 // Spread the donor's circular network toward the square gameplay footprint,
 // with a soft irregular perimeter rather than a cutout mask.
 float square_factor=radius/max(edge,.0001);
 q*=mix(1.,square_factor,.82);
 float angle=atan(q.y,q.x);
 // Uneven perimeter stays outside the required cell coverage.
 float irregular=.065*sin(angle*3.+.7)+.04*sin(angle*2.-1.3);
 float bend=.10*sin(radius*.7+angle*2.)*min(radius/3.,1.);
 q=mat2(vec2(cos(bend),sin(bend)),vec2(-sin(bend),cos(bend)))*q;
 q*=1.+irregular;
 q+=vec2(sin(q.y*1.05+.7),sin(q.x*.87-1.1))*.18*min(radius/3.,1.);
 vec2 side=vec2(-forward_axis.y,forward_axis.x);
 float cross=dot(q,side);float along=dot(q,forward_axis);
 float order=clamp((along+5.3)/10.6,0.,1.);
 float trailing=(1.-order);
 vec2 contact=vec2(1.,1.);
 vec2 folded=contact+side*(cross*.09+sin(along*3.2)*.035*trailing)-forward_axis*(trailing*1.55);
 float folded_height=.06+(.08+.10*cos(cross*2.5))*trailing;
 vec2 from_hit=q-contact;
 float sector=atan(from_hit.y,from_hit.x);
 float stagger=.5+.30*sin(sector*3.+.8)+.20*sin(sector*5.-.6);
 float delay=.02+.24*stagger+length(from_hit)*.008;
 float duration=.62+.40*(.5+.5*sin(sector*2.-1.2));
 float phase=smoothstep(delay,delay+duration,source_clock);
 // Separate sectors pull, hesitate and settle while remaining connected.
 phase=clamp(phase+.075*sin(phase*6.2831853)*sin(sector*3.+1.1),0.,1.);
 VERTEX.xz=mix(folded,q,phase);
 float lift=sin(phase*3.14159265)*(.32+.36*order)*(.8+.2*cos(cross));
 float rest_height=.035+.016*(1.+sin(q.x*2.+q.y*1.7));
 VERTEX.y=mix(folded_height,rest_height,phase)+lift;
 // Small living fold in flight, reaching exactly zero at the shared contact frame.
 VERTEX.y+=source_clock<0.?sin(source_clock*15.+along*2.)*.025*trailing*min(1.,-source_clock*8.):0.;
}
void fragment(){
 vec4 silk=texture(silk_texture,UV);
 ALBEDO=vec3(.65,.68,.61);
 ALPHA=smoothstep(.04,.55,silk.a)*mix(.42,1.,smoothstep(.035,.22,length(UV-vec2(.5))));
}
