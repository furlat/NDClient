shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float cold_age=0.;
const float opacity=1.00000000000000000;
const bool stream=false;
uniform sampler2D edge_noise:repeat_enable,filter_linear;

render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D frost:repeat_enable,filter_linear;
void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;vec3 realp=wp/vec3(1.,.81649658,1.);
 vec2 p=(UV-.5)*24.;float r=length(p);float angle=abs(atan(p.y,max(p.x,.001)));
 float noise=texture(edge_noise,p*.22).r;float flake=texture(edge_noise,p*.85+vec2(.17,.4)).r;
 float side_distance=p.x*tan(.46251225)-abs(p.y);
 float edge_depth=.18+.35*noise;
 float boundary=smoothstep(.02+.12*(1.-noise),edge_depth,side_distance)*(1.-smoothstep(11.15+noise*.50,12.,r));
 float onset=.10+p.x/22.;float local=cold_age-onset;
 float envelope=smoothstep(-.05,.07,local)*(1.-smoothstep(1.05,2.30,local));
 float lace=smoothstep(.62,.80,flake)*(.3+.7*noise);
 ALBEDO=mix(vec3(.17,.37,.49),vec3(.57,.75,.81),lace);
 float frost_group=texture(edge_noise,p*.135+vec2(.27,.13)).r;
 ALPHA=boundary*envelope*(.018+.30*lace*smoothstep(.18,.66,frost_group))*smoothstep(.25,.70,r);

ALPHA*=opacity;

ALPHA *= factory_occurrence_alpha;
}



