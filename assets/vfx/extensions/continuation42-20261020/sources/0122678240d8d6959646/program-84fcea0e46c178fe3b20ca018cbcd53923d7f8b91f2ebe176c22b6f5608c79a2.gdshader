shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
render_mode unshaded,cull_disabled;
uniform float clock=0.;uniform bool rosette=false;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment(){
	
	vec2 p=wp.xz;float r=length(p);float angle=atan(p.y,p.x);float sq=max(abs(p.x),abs(p.y));
	float boundary=1.-smoothstep(4.7,5.3,r);
	float loop_phase=(vfx_package_seconds()+vfx_package_offset_clock)*1.57079632679;
	float n=noise(p*2.7+vec2(cos(loop_phase),sin(loop_phase))*.35);
	float phase=angle*2.+r*3.1-loop_phase;
	float dist=abs(sin(phase*.5));
	float main=1.-smoothstep(.16,.38,dist+.018*(n-.5));
	float hair=1.-smoothstep(.02,.07,abs(sin(phase*.5+.26)));
	float inner=1.-smoothstep(.05,.19,r);
	float advancing=1.;
	float pulse=exp(-pow((r-(vfx_package_seconds()+vfx_package_offset_clock)*7.)/.30,2.));
	float texture=.78+.22*noise(vec2(r*3.+cos(loop_phase)*.35,angle*3.+sin(loop_phase)*.35));
	float env=1.;
	float interference=0.;
	float power=max(inner,main*texture)*advancing;
	if(rosette){
		float blend=.5+.5*sin((vfx_package_seconds()+vfx_package_offset_clock)*1.6);
		float a=pow(max(0.,cos(angle*10.+r*1.7)),3.);
		float b=pow(max(0.,cos(angle*10.+r*1.7+.9)),3.);
		float annulus=smoothstep(.8,1.9,r)*(1.-smoothstep(4.6,5.3,r));
		power=mix(a,b,blend)*annulus*.64;
		env=smoothstep(0.,.3,(vfx_package_seconds()+vfx_package_offset_clock))*(1.-smoothstep(1.5,2.2,(vfx_package_seconds()+vfx_package_offset_clock)));
	}
	float coverage=boundary*env*power;
	if(coverage<.14)discard;
	float hot=smoothstep(.4,.90,power);
	vec3 col=mix(vec3(.61,.16,.25),vec3(.96,.40,.51),hot);
	col=mix(col,vec3(1.,.75,.43),.35*pow(.5+.5*sin(r*1.2-loop_phase),3.));
	col=mix(col,vec3(1.,.89,.77),smoothstep(.65,.98,power*boundary));
	if(rosette)col=mix(vec3(.47,.32,.37),vec3(.71,.47,.51),power);
	ALBEDO=pow(col,vec3(2.2));ALPHA=rosette?.45:(coverage>.38?1.:.75);
}


