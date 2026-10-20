shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_source_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0); uniform float source_clock=0.; uniform vec3 beam_axis=vec3(1,0,0); uniform vec3 beam_origin=vec3(-6.,0.,0.);
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform bool Fresnel_Invert = false;
uniform float Fresnel_Power = 1.0;
uniform sampler2D Gradient_1D_Color : source_color, repeat_disable;
uniform float Vanishing : hint_range(0.0, 1.0) = 1.0;



void fragment() {
vec3 solar_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;float along=dot(solar_world-beam_origin,beam_axis);if(along<0.||along>12.)discard;float reach=12.*smoothstep(.30,.62,(vfx_package_seconds()+vfx_package_offset_source_clock));if(along>reach)discard;

// BooleanParameter:4
	bool n_out4p0 = Fresnel_Invert;


// FloatParameter:3
	float n_out3p0 = Fresnel_Power;


// Fresnel:2
	float n_out2p0 = n_out4p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out3p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out3p0));


	vec4 n_out8p0;
// Texture2D:8
	n_out8p0 = texture(Gradient_1D_Color, vec2(n_out2p0));
	float n_out8p4 = n_out8p0.a;


// Input:5
	vec4 n_out5p0 = COLOR;
	float n_out5p4 = n_out5p0.a;


// VectorOp:9
	vec3 n_out9p0 = vec3(n_out8p0.xyz) * vec3(n_out5p0.xyz);


// FloatOp:6
	float n_out6p0 = n_out8p4 * n_out5p4;


// FloatParameter:11
	float n_out11p0 = Vanishing;


// FloatOp:10
	float n_out10p0 = n_out6p0 * n_out11p0;


// Output:0
	ALBEDO = n_out9p0;
	ALPHA = n_out10p0;


vec3 light_energy=ALBEDO+EMISSION;float energy=max(light_energy.r,max(light_energy.g,light_energy.b));ALPHA*=smoothstep(.025,.24,energy)*(1.-smoothstep(1.8,2.5,(vfx_package_seconds()+vfx_package_offset_source_clock)));float v=clamp(energy,0.,1.);vec3 gold=mix(vec3(.46,.32,.08),vec3(1.,.82,.31),smoothstep(.05,.7,v));gold=mix(gold,vec3(1.,.80,.36),smoothstep(.72,1.2,energy));ALBEDO=gold;EMISSION=vec3(0.);

}


