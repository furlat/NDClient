shader_type spatial;

instance uniform vec4 curse_clock_state : instance_index(0) = vec4(0.0,0.0,1.0,0.0);
instance uniform vec4 curse_frame_x : instance_index(2) = vec4(1.0,0.0,0.0,0.0);
instance uniform vec4 curse_frame_y : instance_index(3) = vec4(0.0,1.0,0.0,0.0);
instance uniform vec4 curse_frame_z : instance_index(4) = vec4(0.0,0.0,1.0,0.0);
instance uniform vec4 curse_frame_w : instance_index(5) = vec4(0.0,0.0,0.0,1.0);
float vfx_package_seconds(){return curse_clock_state.x;}
#define vfx_package_offset_support_clock curse_clock_state.y



#define factory_world_to_source mat4(curse_frame_x,curse_frame_y,curse_frame_z,curse_frame_w)

uniform sampler2D curse_source_palette:filter_nearest,repeat_disable;
uniform int curse_source_palette_count=6;
uniform float curse_source_energy_gain=1.0;
uniform float curse_source_energy_cap=0.823529411765;
float curse_encode(float value){
	value=max(0.0,value);
	return value<=0.0031308?12.92*value:1.055*pow(value,1.0/2.4)-0.055;
}
float curse_decode(float value){
	return value<=0.04045?value/12.92:pow((value+0.055)/1.055,2.4);
}

uniform float support_clock=0.0;

#define support_envelope curse_clock_state.z
render_mode unshaded,cull_disabled;
uniform sampler2D mark_noise;
float stroke(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.,1.));}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

vec2 p=(UV-vec2(.5))*vec2(1.,-1.);
float d=100.0;
d=min(d,stroke(p,vec2(0,-0.29),vec2(0,0.26)));
d=min(d,stroke(p,vec2(-0.26,0.11),vec2(-0.05,0.15)));
d=min(d,stroke(p,vec2(0.08,0.15),vec2(0.26,0.08)));
d=min(d,stroke(p,vec2(-0.26,0.11),vec2(-0.26,-0.11)));
d=min(d,stroke(p,vec2(0.26,0.08),vec2(0.26,-0.23)));
d=min(d,stroke(p,vec2(-0.34,-0.11),vec2(-0.18,-0.11)));
d=min(d,stroke(p,vec2(0.18,-0.23),vec2(0.34,-0.23)));

float core=1.-smoothstep(.022,.031,d);float rim=1.-smoothstep(.036,.043,d);
float n=texture(mark_noise,UV*1.5+vec2((vfx_package_seconds()+vfx_package_offset_support_clock)/2.,-(vfx_package_seconds()+vfx_package_offset_support_clock)/2.)).r;
float edge_light=smoothstep(.62,.90,n)*.10;
ALBEDO=vec3(mix(.13,.57+edge_light,core))*mix(.65,1.,smoothstep(.2,.8,n));ALPHA=rim;


ALPHA *= support_envelope;

	vec3 curse_source_linear=max(ALBEDO+EMISSION,vec3(0.0));
	float curse_energy=curse_encode(max(max(curse_source_linear.r,curse_source_linear.g),curse_source_linear.b));
	curse_energy=min(curse_energy*curse_source_energy_gain,curse_source_energy_cap);
	float curse_index=clamp(floor(pow(clamp(curse_energy,0.0,1.0),1.15)*float(curse_source_palette_count-1)+0.5),0.0,float(curse_source_palette_count-1));
	vec3 curse_choice=texture(curse_source_palette,vec2((curse_index+0.5)/float(curse_source_palette_count),0.5)).rgb;
	ALBEDO=vec3(curse_decode(curse_choice.r),curse_decode(curse_choice.g),curse_decode(curse_choice.b));
	EMISSION=vec3(0.0);
	}


