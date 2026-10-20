shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform vec4 steel_shadow:source_color;
uniform vec4 steel_highlight:source_color;
uniform vec4 gold_shadow:source_color;
uniform vec4 gold_highlight:source_color;

render_mode unshaded,cull_disabled;
uniform int role=0;uniform float height=1.;uniform float opacity=1.;uniform float clock=0.;uniform bool gold=false;
varying vec3 world;varying vec3 normal_world;
void vertex(){world=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;normal_world=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
	
	float reveal=clamp((clock-.65)/.95,0.,1.)*(height+.20);
	if(role==0 && world.y>reveal)discard;
	float release=clamp((clock-4.65)/.85,0.,1.);
	if(role==0 && world.y> (height+.20)*(1.-release))discard;
	float angle=mod(atan(world.z,world.x)+6.2831853,1.5707963)/1.5707963;
	if(role==1 && (angle>clamp((clock-1.35)/.35,0.,1.) || angle<clamp((clock-4.3)/.35,0.,1.)))discard;
	float light=max(0.,dot(normalize(normal_world),normalize(vec3(-.4,.9,.5))));
	vec3 steel=mix(steel_shadow.rgb,steel_highlight.rgb,pow(light,.6));
	float pulse=pow(max(0.,sin(world.y*19.+clock*4.5)),14.);
	ALBEDO=mix(steel,gold_highlight.rgb,pulse*.9);
	if(gold)ALBEDO=mix(gold_shadow.rgb,gold_highlight.rgb,.55+.45*sin(clock*3.-world.y*10.));
	if(role==0 && abs(world.y-reveal)<.045)ALBEDO=gold_highlight.rgb;
	ALPHA=opacity;

EMISSION = gold ? ALBEDO * 0.25 : vec3(0.0);
}



