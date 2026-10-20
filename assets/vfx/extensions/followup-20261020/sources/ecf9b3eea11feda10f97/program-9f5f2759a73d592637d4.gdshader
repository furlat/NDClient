shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float support_clock=0.;
uniform float envelope=1.;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable,filter_linear;
uniform bool wave=false;
void vertex(){VERTEX.y+=sin(VERTEX.x*4.+support_clock*3.)*.035;}
void fragment() {
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz; 

	float n=texture(source_noise,UV*vec2(2.,1.7)+vec2(.10,-.16)*support_clock).r;
	float n2=texture(source_noise,UV*vec2(4.,2.)+vec2(-.08,.08)*support_clock).r;
	float lower=.10+.12*sin(UV.x*19.+n*2.);
	float upper=.66+.15*sin(UV.x*12.+n2*2.);
	float edge=smoothstep(lower,lower+.24,UV.y)*(1.-smoothstep(upper-.20,upper+.12,UV.y));
	if(wave)edge*=smoothstep(0.,.09,UV.x)*(1.-smoothstep(.91,1.,UV.x));
	float fold=.5+.5*sin(UV.x*24.+n*4.+support_clock*1.5);
	float vein=.5+.5*sin(UV.x*13.+UV.y*8.+n*5.-support_clock*2.);
	float value=.035+.30*pow(vein,4.)+.10*pow(fold,8.);
	float rim=exp(-pow((UV.y-(.70+.16*n))/.045,2.));
	ALBEDO=vec3(value+rim*.12);
	ALPHA=edge*(.12+.36*vein+rim*.10);

ALPHA *= envelope;
}



