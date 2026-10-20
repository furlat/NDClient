shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_disabled;
uniform sampler2D frost:repeat_enable,filter_linear;
uniform bool front=false;
void fragment(){
 vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<0.)discard;
 vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);
 float grain=texture(frost,UV*3.7).r;
 float fine=texture(frost,UV*12.3+vec2(.27,.15)).r;
 float facet=.56+.44*max(dot(wn,normalize(vec3(-.3,.8,.5))),0.);
 vec3 body=mix(vec3(.13,.29,.41),vec3(.34,.53,.65),grain);
 float fissure=smoothstep(.66,.88,grain)*smoothstep(.42,.73,fine);
 ALBEDO=mix(body,vec3(.65,.78,.83),fissure*.63)*facet;ALPHA=1.;

ALPHA *= factory_occurrence_alpha;
}





