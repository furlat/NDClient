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

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_schlick_ggx;

uniform vec2 Texture_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Texture : source_color;



void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// ColorConstant:7
	vec4 n_out7p0 = vec4(0.000000, 0.000000, 0.000000, 1.000000);


// Vector2Parameter:6
	vec2 n_out6p0 = Texture_Scale;


// UVFunc:5
	vec2 n_in5p2 = vec2(0.00000, 0.00000);
	vec2 n_out5p0 = (UV - n_in5p2) * n_out6p0 + n_in5p2;


	vec4 n_out4p0;
// Texture2D:4
	n_out4p0 = texture(Disolver_Texture, n_out5p0);
	float n_out4p1 = n_out4p0.r;


// Input:2
	vec4 n_out2p0 = COLOR;
	float n_out2p4 = n_out2p0.a;


// Output:0
	ALBEDO = vec3(n_out7p0.xyz);
	ALPHA = n_out4p1;
	EMISSION = vec3(n_out2p0.xyz);
	ALPHA_SCISSOR_THRESHOLD = n_out2p4;



ALBEDO*=.18; EMISSION*=.18;
ALPHA *= support_envelope;

	vec3 curse_source_linear=max(ALBEDO+EMISSION,vec3(0.0));
	float curse_energy=curse_encode(max(max(curse_source_linear.r,curse_source_linear.g),curse_source_linear.b));
	curse_energy=min(curse_energy*curse_source_energy_gain,curse_source_energy_cap);
	float curse_index=clamp(floor(pow(clamp(curse_energy,0.0,1.0),1.15)*float(curse_source_palette_count-1)+0.5),0.0,float(curse_source_palette_count-1));
	vec3 curse_choice=texture(curse_source_palette,vec2((curse_index+0.5)/float(curse_source_palette_count),0.5)).rgb;
	ALBEDO=vec3(curse_decode(curse_choice.r),curse_decode(curse_choice.g),curse_decode(curse_choice.b));
	EMISSION=vec3(0.0);
	}



