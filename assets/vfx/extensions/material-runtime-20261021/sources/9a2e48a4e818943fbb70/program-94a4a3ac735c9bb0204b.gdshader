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
uniform sampler2D curse_noise;instance uniform float puff_life : instance_index(1) = 0.0;
void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

float coarse=texture(curse_noise,UV*1.15+vec2((vfx_package_seconds()+vfx_package_offset_support_clock)*.07,-(vfx_package_seconds()+vfx_package_offset_support_clock)*.045)).r;
float detail=texture(curse_noise,UV*2.7+vec2(-(vfx_package_seconds()+vfx_package_offset_support_clock)*.12,(vfx_package_seconds()+vfx_package_offset_support_clock)*.09)).r;
float threshold=mix(.30,.94,puff_life);float body=smoothstep(threshold-.07,threshold+.10,coarse);
body*=smoothstep(.18,.64,detail);float edge=(1.-smoothstep(.035,.10,abs(coarse-threshold)))*body;
float contrast=pow(clamp(detail*1.1,0.,1.),1.8);
ALBEDO=vec3(mix(.12,.52,clamp(edge*.70+contrast*.26,0.,1.)));
ALPHA=body*.34*smoothstep(0.,.08,puff_life)*(1.-smoothstep(.58,1.,puff_life));


ALPHA *= support_envelope;

	vec3 curse_source_linear=max(ALBEDO+EMISSION,vec3(0.0));
	float curse_energy=curse_encode(max(max(curse_source_linear.r,curse_source_linear.g),curse_source_linear.b));
	curse_energy=min(curse_energy*curse_source_energy_gain,curse_source_energy_cap);
	float curse_index=clamp(floor(pow(clamp(curse_energy,0.0,1.0),1.15)*float(curse_source_palette_count-1)+0.5),0.0,float(curse_source_palette_count-1));
	vec3 curse_choice=texture(curse_source_palette,vec2((curse_index+0.5)/float(curse_source_palette_count),0.5)).rgb;
	ALBEDO=vec3(curse_decode(curse_choice.r),curse_decode(curse_choice.g),curse_decode(curse_choice.b));
	EMISSION=vec3(0.0);
	}


