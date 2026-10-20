shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform sampler2D authored_noise:repeat_enable,filter_linear;
uniform float clock=0.;uniform float side=1.; varying vec3 local;
void vertex(){
 local=VERTEX;
 float h=max(VERTEX.y,0.)/2.;float d=sin(clock*6.283185+VERTEX.x*2.+VERTEX.z)*.018*h*h;
 VERTEX.xz*=1.+d;
}
void fragment(){
 if(local.y<0.)discard;
 vec3 w=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
 
 vec3 p=normalize(local);
 vec2 offset=vec2(cos(clock*6.283185),sin(clock*6.283185))*.055;
 float f=texture(authored_noise,p.xy*1.5+offset).r*.5+texture(authored_noise,p.zy*1.7-offset).r*.5;
 float edge=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),1.8);
 float patches=smoothstep(.35,.70,f);
 ALBEDO=mix(vec3(.16,.08,.34),vec3(.55,.43,.77),edge*.65+patches*.25);
 ALPHA=.025+patches*(.035+.10*edge)+edge*.18;

ALPHA *= factory_occurrence_alpha;
}




