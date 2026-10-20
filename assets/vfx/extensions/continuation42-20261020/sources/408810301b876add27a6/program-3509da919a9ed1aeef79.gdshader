shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
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
uniform float support_envelope=1.0;render_mode unshaded,cull_disabled,depth_draw_never;
uniform float ring_phase=0.;uniform bool releasing=false;varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

float angle=atan(local_position.z,local_position.x);
float travel=sin(angle*3.-(vfx_package_seconds()+vfx_package_offset_support_clock)*3.14159265359+ring_phase);
float accent=smoothstep(.70,.99,travel);
ALBEDO=vec3(.53+.09*accent);EMISSION=vec3(.008*accent);ALPHA=.88;
if(releasing){float cut=.28+.25*sin(angle*5.+ring_phase);ALPHA*=1.-smoothstep(cut,cut+.30,(vfx_package_seconds()+vfx_package_offset_support_clock));}


ALPHA *= support_envelope;

	vec3 curse_source_linear=max(ALBEDO+EMISSION,vec3(0.0));
	float curse_energy=curse_encode(max(max(curse_source_linear.r,curse_source_linear.g),curse_source_linear.b));
	curse_energy=min(curse_energy*curse_source_energy_gain,curse_source_energy_cap);
	float curse_index=clamp(floor(pow(clamp(curse_energy,0.0,1.0),1.15)*float(curse_source_palette_count-1)+0.5),0.0,float(curse_source_palette_count-1));
	vec3 curse_choice=texture(curse_source_palette,vec2((curse_index+0.5)/float(curse_source_palette_count),0.5)).rgb;
	ALBEDO=vec3(curse_decode(curse_choice.r),curse_decode(curse_choice.g),curse_decode(curse_choice.b));
	EMISSION=vec3(0.0);
	}


