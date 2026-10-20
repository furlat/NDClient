shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_source_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0); uniform float source_clock=0.; uniform vec3 beam_axis=vec3(1,0,0); uniform vec3 beam_origin=vec3(-6.,0.,0.);
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D Alpha_Texture : source_color, filter_linear;
uniform float ProximityFade = 0.5;
uniform sampler2D depth_tex_frg_6 : hint_depth_texture;



void vertex() {
	mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __wm = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		__wm = __wm * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		__wm = __wm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = VIEW_MATRIX * __wm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;


}

void fragment() {
vec3 solar_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;float along=dot(solar_world-beam_origin,beam_axis);if(along<0.||along>12.)discard;float reach=12.*smoothstep(.30,.62,(vfx_package_seconds()+vfx_package_offset_source_clock));if(along>reach)discard;

// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Alpha_Texture, UV);
	float n_out3p1 = n_out3p0.r;


// FloatOp:8
	float n_out8p0 = n_out4p4 * n_out3p1;


// FloatParameter:7
	float n_out7p0 = ProximityFade;


	float n_out6p0;
// ProximityFade:6
	{
		float __depth_tex = texture(depth_tex_frg_6, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out6p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out7p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:5
	float n_out5p0 = n_out8p0 * n_out6p0;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out5p0;


vec3 light_energy=ALBEDO+EMISSION;float energy=max(light_energy.r,max(light_energy.g,light_energy.b));ALPHA*=smoothstep(.025,.24,energy)*(1.-smoothstep(1.8,2.5,(vfx_package_seconds()+vfx_package_offset_source_clock)));float v=clamp(energy,0.,1.);vec3 gold=mix(vec3(.46,.32,.08),vec3(1.,.82,.31),smoothstep(.05,.7,v));gold=mix(gold,vec3(1.,.80,.36),smoothstep(.72,1.2,energy));ALBEDO=gold;EMISSION=vec3(0.);

}


