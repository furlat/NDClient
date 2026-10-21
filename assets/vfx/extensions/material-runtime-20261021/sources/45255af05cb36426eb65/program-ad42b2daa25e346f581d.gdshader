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

render_mode blend_mix, depth_draw_always, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Cloud_Color_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Dark_variation : source_color, filter_linear;
uniform sampler2D Dark_Color_Gradient_1D : source_color, filter_linear;
uniform vec2 Dissapear_scale = vec2(1.000000, 1.000000);
uniform sampler2D Disapear_Noise : source_color, filter_linear, repeat_enable;
uniform sampler2D Emission_1D_Gradient_Timed : source_color;
uniform vec2 Noise_color_scale = vec2(1.000000, 1.000000);
uniform sampler2D Noise_Color : source_color;



void fragment() {
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Vector2Parameter:50
	vec2 n_out50p0 = Cloud_Color_Scale;


// UVFunc:49
	vec2 n_in49p2 = vec2(0.00000, 0.00000);
	vec2 n_out49p0 = (UV - n_in49p2) * n_out50p0 + n_in49p2;


	vec4 n_out43p0;
// Texture2D:43
	n_out43p0 = texture(Dark_variation, n_out49p0);
	float n_out43p1 = n_out43p0.r;


	vec4 n_out45p0;
// Texture2D:45
	n_out45p0 = texture(Dark_Color_Gradient_1D, vec2(n_out43p1));


// Vector2Parameter:51
	vec2 n_out51p0 = Dissapear_scale;


// UVFunc:52
	vec2 n_in52p2 = vec2(0.00000, 0.00000);
	vec2 n_out52p0 = (UV - n_in52p2) * n_out51p0 + n_in52p2;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Disapear_Noise, n_out52p0);
	float n_out38p1 = n_out38p0.r;


// Input:36
	vec4 n_out36p0 = COLOR;
	float n_out36p4 = n_out36p0.a;


	vec4 n_out56p0;
// Texture2D:56
	n_out56p0 = texture(Emission_1D_Gradient_Timed, vec2(n_out36p4));
	float n_out56p1 = n_out56p0.r;


// Vector2Parameter:53
	vec2 n_out53p0 = Noise_color_scale;


// UVFunc:54
	vec2 n_in54p2 = vec2(0.00000, 0.00000);
	vec2 n_out54p0 = (UV - n_in54p2) * n_out53p0 + n_in54p2;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Noise_Color, n_out54p0);
	float n_out9p1 = n_out9p0.r;


// SmoothStep:10
	float n_in10p1 = 1.00000;
	float n_out10p0 = smoothstep(n_out56p1, n_in10p1, n_out9p1);


// VectorOp:13
	vec4 n_out13p0 = n_out36p0 * vec4(n_out10p0);


// Input:33
	vec4 n_out33p0 = COLOR;
	float n_out33p4 = n_out33p0.a;


// Output:0
	ALBEDO = vec3(n_out45p0.xyz);
	ALPHA = n_out38p1;
	EMISSION = vec3(n_out13p0.xyz);
	ALPHA_SCISSOR_THRESHOLD = n_out33p4;



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



