shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

render_mode unshaded,cull_disabled;
uniform vec3 dark_tone; uniform vec3 mid_tone; uniform vec3 light_tone;
uniform float clock=0.; uniform float strength=1.;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),1.7);
	float lit=clamp(dot(normalize(NORMAL),normalize(vec3(-.35,.8,.5)))*.38+.45,0.,1.);
	float vein=pow(.5+.5*sin(local.x*24.+local.z*17.+(vfx_package_seconds()+vfx_package_offset_clock)*6.28318),16.);
	float energy=clamp(lit*.6+rim*.55+vein*.13,0.,1.);
	vec3 c=mix(dark_tone,mid_tone,smoothstep(.05,.55,energy));
	c=mix(c,light_tone,smoothstep(.56,.92,energy));
	ALBEDO=c; EMISSION=c*.14*strength;
	float lace=.5+.22*sin(local.x*31.+local.y*19.+(vfx_package_seconds()+vfx_package_offset_clock)*6.28318)+.22*sin(local.z*33.-local.y*21.-(vfx_package_seconds()+vfx_package_offset_clock)*12.56636);
	ALPHA=(.26+rim*.70)*smoothstep(.12,.58,lace);
}

