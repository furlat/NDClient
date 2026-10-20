shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
// curse_ground_marker
uniform sampler2D curse_noise;
uniform float curse_age=0.0;
void fragment(){
	vec2 p=(UV-vec2(0.5))*2.0;
	float age=curse_age;
	float shrink=mix(0.86,1.16,smoothstep(0.05,0.6,age));
	vec2 q=p*shrink;
	float n=texture(curse_noise,UV*1.9+vec2(age*0.12,-age*0.08)).r;
	float a=atan(q.y,q.x);
	float lobe=0.69+0.11*sin(a*3.0+0.4)+0.075*cos(a*5.0-0.8);
	float r=length(q)+(n-0.5)*0.2;
	float edge=1.0-smoothstep(0.04,0.13,abs(r-lobe));
	float body=(1.0-smoothstep(lobe-0.13,lobe+0.08,r))*smoothstep(0.05,0.36,r);
	float torn=smoothstep(0.30,0.58,n);
	float env=smoothstep(0.02,0.14,age)*(1.0-smoothstep(0.4,0.95,age));
	float pulse=1.0+0.45*exp(-pow((age-0.23)/0.1,2.0));
	ALBEDO=mix(vec3(0.09,0.008,0.022),vec3(0.72,0.025,0.04),edge*torn);
	ALPHA=(body*0.40+edge*torn*0.7)*env*pulse;

ALPHA *= 1.0;
}


