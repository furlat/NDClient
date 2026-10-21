shader_type spatial;
uniform sampler2D owner_cells : filter_nearest, repeat_disable;
uniform ivec2 owner_mask_origin = ivec2(0);
uniform vec3 owner_world_anchor = vec3(0.0);
uniform int owner_cut_count = 0;
uniform vec4 owner_cuts[64];

global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_vfx_clock=0.0;
uniform float vfx_package_offset_age=0.0;
uniform float vfx_package_offset_destroy_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);uniform float vfx_clock=0.0;uniform float age=0.0;uniform float opacity=1.0;uniform float destroy_age=-1.0;uniform vec3 impact;uniform vec2 camera_sign;uniform bool front=false;uniform bool dome=false;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform float Size_Sphere = 0.0;
uniform float Gradient_Line : hint_range(0.0, 0.83999997377396) = 0.0;
uniform float Line_Baias = 0.01999999955297;
uniform float SmoothStep : hint_range(0.0, 1.0) = 0.80000001192093;
uniform vec2 Disolver_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Noise_Line : source_color, filter_linear, repeat_enable;
uniform float Line_Distortion_Divider = 5.0;
uniform sampler2D Gradient_Disappear : source_color, filter_linear, repeat_disable;
uniform sampler2D Line_Gradient : source_color, filter_linear, repeat_disable;
uniform vec2 Overlay_Scale = vec2(1.000000, 1.000000);
uniform vec2 Overlay_Velocity = vec2(0.000000, 0.000000);
uniform sampler2D Overlay_Texture : source_color, hint_default_black, filter_linear;
uniform float Overlay_Power = 2.0;
uniform float Proximity_light = 0.5;
uniform sampler2D depth_tex_frg_31 : hint_depth_texture;
uniform float Proximity_Power = 0.5;
uniform bool Fresnel_invert;
uniform float fresnel_power = 0.68300002813339;
uniform float darkness = 0.0;
uniform sampler2D Gradient_1D_Color : source_color, filter_linear;



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// Input:4
	vec3 n_out4p0 = NORMAL;


// FloatParameter:6
	float n_out6p0 = Size_Sphere;


// VectorOp:5
	vec3 n_out5p0 = n_out4p0 * vec3(n_out6p0);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out5p0;


// Output:0
	VERTEX = n_out3p0;


}

void fragment() {
vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;bool nearest=dot(wp.xz,camera_sign)>0.0;

// FloatParameter:56
	float n_out56p0 = Gradient_Line;


// FloatParameter:61
	float n_out61p0 = Line_Baias;


// FloatOp:59
	float n_out59p0 = n_out56p0 - n_out61p0;


// FloatParameter:95
	float n_out95p0 = SmoothStep;


// Input:78
	vec2 n_out78p0 = UV;


// Vector2Parameter:83
	vec2 n_out83p0 = Disolver_Scale;


// UVFunc:82
	vec2 n_in82p2 = vec2(0.00000, 0.00000);
	vec2 n_out82p0 = (UV - n_in82p2) * n_out83p0 + n_in82p2;


	vec4 n_out77p0;
// Texture2D:77
	n_out77p0 = texture(Disolver_Noise_Line, n_out82p0);
	float n_out77p1 = n_out77p0.r;


// FloatParameter:91
	float n_out91p0 = Line_Distortion_Divider;


// FloatOp:80
	float n_out80p0 = n_out77p1 / n_out91p0;


// VectorOp:79
	vec2 n_out79p0 = n_out78p0 + vec2(n_out80p0);


	vec4 n_out86p0;
// Texture2D:86
	n_out86p0 = texture(Gradient_Disappear, n_out79p0);
	float n_out86p1 = n_out86p0.r;


// FloatOp:94
	float n_in94p1 = 0.59000;
	float n_out94p0 = pow(n_out86p1, n_in94p1);


// SmoothStep:84
	float n_out84p0 = smoothstep(n_out59p0, n_out95p0, n_out94p0);


	vec4 n_out90p0;
// Texture2D:90
	n_out90p0 = texture(Line_Gradient, vec2(n_out84p0));


// Input:50
	vec2 n_out50p0 = UV;


// Vector2Parameter:43
	vec2 n_out43p0 = Overlay_Scale;


// UVFunc:42
	vec2 n_in42p2 = vec2(0.00000, 0.00000);
	vec2 n_out42p0 = (n_out50p0 - n_in42p2) * n_out43p0 + n_in42p2;


// Vector2Parameter:44
	vec2 n_out44p0 = Overlay_Velocity;


// Input:47
	float n_out47p0 = (vfx_package_seconds()+vfx_package_offset_vfx_clock);


// VectorOp:45
	vec2 n_out45p0 = n_out44p0 * vec2(n_out47p0);


// UVFunc:46
	vec2 n_in46p1 = vec2(1.00000, 1.00000);
	vec2 n_out46p0 = n_out45p0 * n_in46p1 + n_out42p0;


	vec4 n_out41p0;
// Texture2D:41
	n_out41p0 = texture(Overlay_Texture, fract(n_out46p0));
	float n_out41p1 = n_out41p0.r;


// FloatParameter:49
	float n_out49p0 = Overlay_Power;


// FloatOp:48
	float n_out48p0 = pow(n_out41p1, n_out49p0);


// FloatParameter:34
	float n_out34p0 = Proximity_light;


	float n_out31p0;
// ProximityFade:31
	{
		float __depth_tex = texture(depth_tex_frg_31, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out31p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_out34p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatParameter:36
	float n_out36p0 = Proximity_Power;


// FloatOp:35
	float n_out35p0 = pow(n_out31p0, n_out36p0);


// FloatFunc:33
	float n_out33p0 = 1.0 - n_out35p0;


// BooleanParameter:19
	bool n_out19p0 = Fresnel_invert;


// FloatParameter:14
	float n_out14p0 = fresnel_power;


// Fresnel:11
	float n_out11p0 = n_out19p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out14p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out14p0));


// FloatOp:32
	float n_out32p0 = n_out33p0 + n_out11p0;


// FloatOp:39
	float n_out39p0 = n_out48p0 * 0.14 + n_out32p0;


// Clamp:25
	float n_in25p1 = 0.00000;
	float n_in25p2 = 1.00000;
	float n_out25p0 = clamp(n_out39p0, n_in25p1, n_in25p2);


// FloatParameter:15
	float n_out15p0 = darkness;


// FloatOp:13
	float n_out13p0 = n_out25p0 - n_out15p0;


// FloatOp:97
	float n_out97p0 = n_out13p0;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Gradient_1D_Color, vec2(n_out97p0));
	float n_out38p4 = n_out38p0.a;


// VectorOp:63
	vec3 n_out63p0 = vec3(n_out90p0.xyz) + vec3(n_out38p0.xyz);


// Step:57
	float n_out57p0 = step(n_out86p1, n_out56p0);


// FloatOp:96
	float n_out96p0 = n_out38p4 * n_out57p0;


// Output:0
	ALBEDO = n_out63p0;
	ALPHA = n_out96p0;



	float growth=smoothstep(0.0,0.85,(vfx_package_seconds()+vfx_package_offset_age));
	if(wp.y>growth*4.242640688)discard;
	float crest=exp(-pow((wp.y-growth*4.242640688)/.14,2.0))*(1.0-smoothstep(.65,.95,(vfx_package_seconds()+vfx_package_offset_age)));
	float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
	float energy=smoothstep(.0008,.009,abs(COLOR.r));
	float distance_from_contact=length(wp-impact);
	float travel=max(0.0,(vfx_package_seconds()+vfx_package_offset_destroy_age))*15.0;
	float dissolution=smoothstep(distance_from_contact*.035,distance_from_contact*.035+.5,(vfx_package_seconds()+vfx_package_offset_destroy_age));
	float destabilize=exp(-pow((distance_from_contact-travel)/.45,2.0))*step(0.0,(vfx_package_seconds()+vfx_package_offset_destroy_age));
	float line=clamp(n_out48p0,0.0,1.0);
	float border=dome?exp(-pow(wp.y/.05,2.0)):max(exp(-pow((abs(wp.x)-6.363961032)/.045,2.0)),max(exp(-pow(wp.y/.045,2.0)),exp(-pow((wp.y-4.242640688)/.045,2.0))));
	ALBEDO=mix(vec3(.07,.26,.49),vec3(.38,.67,1.0),max(max(line*.65,rim),border*.4));
	ALBEDO=mix(ALBEDO,vec3(.65,1.15,1.7),max(crest,max(energy,destabilize)));
	ALPHA=(.065+.12*line+.10*rim+.30*border+.60*crest+.75*energy+.45*destabilize)*opacity*growth*(1.0-dissolution);
	
EMISSION=ALBEDO*0.38;

vec3 owner_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz-owner_world_anchor;
ivec2 owner_cell=ivec2(floor(owner_world.xz+vec2(0.5)))-owner_mask_origin;
ivec2 owner_size=textureSize(owner_cells,0);
if(any(lessThan(owner_cell,ivec2(0)))||any(greaterThanEqual(owner_cell,owner_size)))discard;
if(texelFetch(owner_cells,owner_cell,0).r<0.5)discard;
for(int owner_i=0;owner_i<owner_cut_count;owner_i++){
vec3 owner_delta=owner_world-owner_cuts[owner_i].xyz;
if(all(greaterThanEqual(owner_delta,vec3(0.0)))&&all(lessThan(owner_delta,vec3(2.0,1.632993161855452,2.0))))discard;
}
}


