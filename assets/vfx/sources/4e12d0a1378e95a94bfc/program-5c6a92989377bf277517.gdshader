shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float cold_age=0.;
const float opacity=1.00000000000000000;
const bool stream=false;
uniform sampler2D edge_noise:repeat_enable,filter_linear;
render_mode unshaded,cull_disabled;
uniform sampler2D frost:repeat_enable,filter_linear;
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;vec3 realp=wp/vec3(1.,.81649658,1.);float depth=wp.x+wp.z;float cold_partition=smoothstep(4.260000000000,4.740000000000,depth)*(1.-smoothstep(8.760000000000,9.240000000000,depth));
 vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);float facet=.45+.55*max(dot(wn,normalize(vec3(-.3,.8,.5))),0.);
 float n=texture(frost,UV*2.).r;ALBEDO=mix(vec3(.28,.55,.70),vec3(.55,.76,.85),n)*facet;ALPHA=1.;

ALPHA*=opacity;
float r=length(realp.xz);float angular=abs(atan(realp.z,max(realp.x,.001)));
	float grain=texture(edge_noise,realp.xz*.21).r;
	ALPHA*=smoothstep(-.03,.18,realp.y)*(1.-smoothstep(11.5+grain*.23,12.,r))*smoothstep(.015+.12*(1.-grain),.18+.34*grain,realp.x*tan(.46251225)-abs(realp.z));
	if(stream){float travel=realp.x/22.;float local_age=cold_age-.10-travel;ALPHA*=pow(abs(dot(NORMAL,VIEW)),.65);ALPHA*=smoothstep(-.08,.06,local_age)*(1.-smoothstep(.58,.98,local_age));}

ALPHA*=cold_partition;

ALPHA *= factory_occurrence_alpha;
}




void vertex(){mat3 cone_basis=mat3(MODELVIEW_MATRIX);if(determinant(cone_basis)!=0.0){MODELVIEW_NORMAL_MATRIX=transpose(inverse(cone_basis));}}
