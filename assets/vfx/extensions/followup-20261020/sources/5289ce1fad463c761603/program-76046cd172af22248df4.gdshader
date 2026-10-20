shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D corruption_noise : filter_linear, repeat_enable;
uniform sampler2D Mask_Texture : source_color, filter_linear;
uniform float Proximity_fade : hint_range(0.0, 1.0) = 0.30000001192093;
uniform sampler2D depth_tex_frg_7 : hint_depth_texture;



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
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Mask_Texture, UV);
	float n_out3p1 = n_out3p0.r;


// FloatOp:5
	float n_out5p0 = n_out4p4 * n_out3p1;


// FloatParameter:8
	float n_out8p0 = Proximity_fade;


	float n_out7p0;
// ProximityFade:7
	{
		float __depth_tex = texture(depth_tex_frg_7, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out7p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out8p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatOp:6
	float n_out6p0 = n_out5p0 * n_out7p0;


// Output:0
	
	float grain=texture(corruption_noise,UV*1.9+vec2(support_clock*0.11,-support_clock*0.08)).r;
	float radius=length((UV-vec2(0.5))*vec2(1.35,0.92));
	float edge=radius+(grain-0.5)*0.105;
	float core=(1.0-smoothstep(0.17,0.225,edge))*(1.0-smoothstep(0.51,0.74,UV.x));
	float rim=smoothstep(0.125,0.17,edge)*(1.0-smoothstep(0.18,0.225,edge));
	ALBEDO=mix(vec3(0.045),vec3(0.9),rim*0.96+n_out3p1*0.04);
	
	ALPHA = max(core*0.18,n_out3p1*0.28)*n_out4p4;



ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}





