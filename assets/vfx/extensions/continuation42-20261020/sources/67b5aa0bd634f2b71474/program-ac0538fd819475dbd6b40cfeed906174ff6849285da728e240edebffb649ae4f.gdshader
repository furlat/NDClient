shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_source_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0); uniform float source_clock=0.; uniform vec3 beam_axis=vec3(1,0,0); uniform vec3 beam_origin=vec3(-6.,0.,0.);
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform float Color_Intensity = 1.0;
uniform vec2 Scale_XY = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Base_Texture : source_color;
uniform sampler2D Add_Texture : source_color, repeat_disable;
uniform sampler2D Substract_Texture : source_color, hint_default_black, repeat_disable;
uniform sampler2D Gradient_1D_Color : source_color;
uniform float Dissolver_edge : hint_range(0.0, 1.0) = 0.0;



void fragment() {
vec3 solar_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;float along=dot(solar_world-beam_origin,beam_axis);if(along<0.||along>12.)discard;float reach=12.*smoothstep(.30,.62,(vfx_package_seconds()+vfx_package_offset_source_clock));if(along>reach)discard;

// FloatParameter:27
	float n_out27p0 = Color_Intensity;


// Vector2Parameter:13
	vec2 n_out13p0 = Scale_XY;


// UVFunc:9
	vec2 n_in9p2 = vec2(0.00000, 0.00000);
	vec2 n_out9p0 = (UV - n_in9p2) * n_out13p0 + n_in9p2;


// Vector2Parameter:10
	vec2 n_out10p0 = Speed_XY;


// Input:12
	float n_out12p0 = (vfx_package_seconds()+vfx_package_offset_source_clock);


// VectorOp:11
	vec2 n_out11p0 = n_out10p0 * vec2(n_out12p0);


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out11p0 * n_in8p1 + n_out9p0;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Base_Texture, n_out8p0);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out6p0;
// Texture2D:6
	n_out6p0 = texture(Add_Texture, UV);
	float n_out6p1 = n_out6p0.r;


// FloatOp:24
	float n_out24p0 = n_out3p1 + n_out6p1;


	vec4 n_out30p0;
// Texture2D:30
	n_out30p0 = texture(Substract_Texture, UV);
	float n_out30p1 = n_out30p0.r;


// FloatOp:32
	float n_out32p0 = n_out24p0 - n_out30p1;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out32p0, n_in25p1, n_in25p2);


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Gradient_1D_Color, vec2(n_out25p0));
	float n_out15p4 = n_out15p0.a;


// VectorOp:26
	vec3 n_out26p0 = vec3(n_out27p0) * vec3(n_out15p0.xyz);


// FloatParameter:29
	float n_out29p0 = Dissolver_edge;


// SmoothStep:28
	float n_in28p1 = 1.00000;
	float n_out28p0 = smoothstep(n_out29p0, n_in28p1, n_out15p4);


// Output:0
	ALBEDO = n_out26p0;
	ALPHA = n_out28p0;


vec3 light_energy=ALBEDO+EMISSION;float energy=max(light_energy.r,max(light_energy.g,light_energy.b));ALPHA*=smoothstep(.025,.24,energy)*(1.-smoothstep(1.8,2.5,(vfx_package_seconds()+vfx_package_offset_source_clock)));float v=clamp(energy,0.,1.);vec3 gold=mix(vec3(.46,.32,.08),vec3(1.,.82,.31),smoothstep(.05,.7,v));gold=mix(gold,vec3(1.,.80,.36),smoothstep(.72,1.2,energy));ALBEDO=gold;EMISSION=vec3(0.);

}


