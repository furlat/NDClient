shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D noise_tex:repeat_enable,filter_linear;
uniform float impact_age=0.;
uniform bool visible_hit=false;
uniform bool front=false;
void fragment(){
 vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
 vec2 p=UV*2.-1.;float r=length(p);float n=texture(noise_tex,UV*3.).r;
 float spread=.12+impact_age*2.6;
 float dust=(1.-smoothstep(spread-.20,spread+.08,r))*(1.-smoothstep(.05,.42,impact_age));
 ALBEDO=vec3(.42,.63,.74);ALPHA=dust*smoothstep(.40,.72,n)*.24*float(visible_hit);

ALPHA *= factory_occurrence_alpha;
}





