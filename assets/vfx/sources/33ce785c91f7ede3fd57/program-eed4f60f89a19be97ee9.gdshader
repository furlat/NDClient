shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_wind_clock=0.0;

instance uniform vec4 wind_segment_start = vec4(0.0);
instance uniform vec4 wind_segment_end = vec4(1.0, 0.0, 0.0, 1.0);
instance uniform vec4 wind_segment_normal_start = vec4(0.0, 0.0, 1.0, 1.0);
instance uniform vec4 wind_segment_normal_end = vec4(0.0, 0.0, 1.0, 0.0);
uniform float wind_sheet_offset = 0.0;

uniform float factory_occurrence_alpha=1.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform sampler2D wind_macro_noise:repeat_enable,filter_linear;
uniform float wind_macro_phase=0.0;
uniform float wind_clock=0.0;uniform float reveal=0.0;uniform float wall_opacity=1.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;uniform bool split_layers=false;uniform float formation_pulse=0.0;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float scroll_offset : hint_range(-2.0, 0.0) = 0.0;
uniform vec2 speed = vec2(0.000000, 1.000000);
uniform vec2 scale = vec2(1.000000, 1.000000);
uniform sampler2D BaseTexture : source_color, repeat_disable;
uniform vec2 wind_speed = vec2(0.000000, -1.000000);
uniform vec2 wind_scale = vec2(1.000000, 1.000000);
uniform sampler2D Wind_1_texture : source_color, repeat_enable;
uniform vec2 wind_2_speed = vec2(0.000000, 1.200000);
uniform vec2 wind_2_scale = vec2(1.000000, 1.000000);
uniform sampler2D Wind_2_texture_subs : source_color, hint_default_black, repeat_enable;
uniform sampler2D Multiply_Mask : source_color, repeat_disable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;



void vertex() {
float wind_unit_u = UV.x;
float wind_unit_y = UV.y;
vec3 wind_center = mix(wind_segment_start.xyz, wind_segment_end.xyz, wind_unit_u);
vec3 wind_side = mix(wind_segment_normal_start.xyz, wind_segment_normal_end.xyz, wind_unit_u);
float wind_interior = sin(3.14159265358979323846 * wind_unit_u);
wind_interior *= wind_interior;
float wind_shape = sin(wind_unit_y * 9.0 + wind_segment_normal_end.w * 2.1) * wind_interior * 0.025;
VERTEX = wind_center + vec3(0.0, wind_unit_y * 6.363961032, 0.0)
    + wind_side * (wind_sheet_offset + wind_shape);
NORMAL = normalize(wind_side);
UV = vec2(mix(wind_segment_start.w, wind_segment_end.w, wind_unit_u)
    / wind_segment_normal_start.w * round(wind_segment_normal_start.w / 2.121320344 * 1.7), wind_unit_y);

// Input:3
	vec4 n_out3p0 = vec4(1.0,1.0,1.0,(vfx_package_seconds()+vfx_package_offset_wind_clock));
	float n_out3p1 = n_out3p0.r;
	float n_out3p2 = n_out3p0.g;


// VectorCompose:7
	vec3 n_out7p0 = vec3(n_out3p2, n_out3p1, n_out3p2);


// Input:2
	vec3 n_out2p0 = VERTEX;


// VectorOp:4
	vec3 n_out4p0 = n_out7p0 * n_out2p0;


// Output:0
	VERTEX = n_out4p0; VERTEX+=NORMAL*(.045*sin(UV.x*6.2831853+UV.y*3.0-(vfx_package_seconds()+vfx_package_offset_wind_clock)*3.14159265)+.018*sin(UV.x*12.5663706+UV.y*7.0+(vfx_package_seconds()+vfx_package_offset_wind_clock)*6.2831853))*smoothstep(0.0,.2,UV.y);


vec3 wp=(factory_world_to_source * MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;vec2 offset=wp.xz-actor_ground;float d=length(offset);float near_body=(1.0-smoothstep(.30,1.50,d))*smoothstep(0.0,.30,wp.y)*(1.0-smoothstep(2.15,3.1,wp.y));wp.xz+=offset/max(.12,d)*near_body*.32;VERTEX=(inverse(MODEL_MATRIX)*inverse(factory_world_to_source)*vec4(wp,1.0)).xyz;
}

void fragment() {
// Vector2Parameter:41
	vec2 n_out41p0 = speed;


// Input:37
	vec4 n_out37p0 = vec4(1.0,1.0,1.0,(vfx_package_seconds()+vfx_package_offset_wind_clock));
	float n_out37p4 = n_out37p0.a;


// FloatParameter:47
	float n_out47p0 = scroll_offset;


// FloatOp:48
	float n_out48p0 = n_out37p4 + n_out47p0;


// VectorOp:42
	vec2 n_out42p0 = n_out41p0 * vec2(n_out48p0);


// UVFunc:7
	vec2 n_in7p1 = vec2(1.00000, 1.00000);
	vec2 n_out7p0 = n_out42p0 * n_in7p1 + UV;


// Vector2Parameter:5
	vec2 n_out5p0 = scale;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (n_out7p0 - n_in4p2) * n_out5p0 + n_in4p2;


	vec4 n_out8p0;
// Texture2D:8
	n_out8p0 = texture(BaseTexture, n_out4p0);
	float n_out8p1 = n_out8p0.r;


// Vector2Parameter:43
	vec2 n_out43p0 = wind_speed;


// Input:35
	vec4 n_out35p0 = vec4(1.0,1.0,1.0,(vfx_package_seconds()+vfx_package_offset_wind_clock));
	float n_out35p4 = n_out35p0.a;


// ParameterRef:51
	float n_out51p0 = scroll_offset;


// FloatOp:50
	float n_out50p0 = n_out35p4 + n_out51p0;


// VectorOp:44
	vec2 n_out44p0 = n_out43p0 * vec2(n_out50p0);


// UVFunc:27
	vec2 n_in27p1 = vec2(1.00000, 1.00000);
	vec2 n_out27p0 = n_out44p0 * n_in27p1 + UV;


// Vector2Parameter:26
	vec2 n_out26p0 = wind_scale;


// UVFunc:25
	vec2 n_in25p2 = vec2(0.00000, 0.00000);
	vec2 n_out25p0 = (n_out27p0 - n_in25p2) * n_out26p0 + n_in25p2;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Wind_1_texture, n_out25p0);
	float n_out18p1 = n_out18p0.r;


// Reroute:39
	float n_out39p0 = n_out18p1;


// Vector2Parameter:45
	vec2 n_out45p0 = wind_2_speed;


// Input:36
	vec4 n_out36p0 = vec4(1.0,1.0,1.0,(vfx_package_seconds()+vfx_package_offset_wind_clock));
	float n_out36p4 = n_out36p0.a;


// ParameterRef:52
	float n_out52p0 = scroll_offset;


// FloatOp:53
	float n_out53p0 = n_out36p4 + n_out52p0;


// VectorOp:46
	vec2 n_out46p0 = n_out45p0 * vec2(n_out53p0);


// UVFunc:30
	vec2 n_in30p1 = vec2(1.00000, 1.00000);
	vec2 n_out30p0 = n_out46p0 * n_in30p1 + UV;


// Vector2Parameter:31
	vec2 n_out31p0 = wind_2_scale;


// UVFunc:29
	vec2 n_in29p2 = vec2(0.00000, 0.00000);
	vec2 n_out29p0 = (n_out30p0 - n_in29p2) * n_out31p0 + n_in29p2;


	vec4 n_out20p0;
// Texture2D:20
	n_out20p0 = texture(Wind_2_texture_subs, n_out29p0);
	float n_out20p1 = n_out20p0.r;


// Reroute:40
	float n_out40p0 = n_out20p1;


// FloatOp:22
	float n_out22p0 = n_out39p0 - n_out40p0;


// FloatOp:19
	float n_out19p0 = n_out8p1 * n_out22p0;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Multiply_Mask, UV);
	float n_out11p1 = n_out11p0.r;


// FloatOp:12
	float n_out12p0 = n_out19p0 * n_out11p1;


	vec4 n_out13p0;
// Texture2D:13
	n_out13p0 = texture(Color1DGradient, vec2(n_out12p0));
	float n_out13p4 = n_out13p0.a;


// Output:0
	ALBEDO = vec3(n_out13p0.xyz);
	ALPHA = n_out13p4;



float vertical=smoothstep(0.0,.035,UV.y)*(1.0-smoothstep(.79,1.0,UV.y));float grow=1.0-smoothstep(reveal-.10,reveal,UV.y);ALPHA*=wall_opacity*vertical*grow;ALBEDO=vec3(.73,.83,.89)+vec3(.14)*clamp(ALPHA,0.0,1.0);vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;float local_hit=1.0-smoothstep(.35,1.8,length(wp-vec3(actor_ground.x,1.2,actor_ground.y)));float body_clear=(1.0-smoothstep(.35,1.0,length(wp.xz-actor_ground)))*smoothstep(.15,.50,wp.y)*(1.0-smoothstep(2.1,2.8,wp.y));ALPHA*=1.0-.68*body_clear;ALPHA*=1.0+formation_pulse*local_hit*.65;

float wind_macro=texture(wind_macro_noise,vec2(UV.x*.13+wind_macro_phase,UV.y*.7)+.12*vec2(cos((vfx_package_seconds()+vfx_package_offset_wind_clock)*3.14159265359),sin((vfx_package_seconds()+vfx_package_offset_wind_clock)*3.14159265359))).r;
ALPHA *= .16+.52*smoothstep(.22,.72,wind_macro);

ALPHA *= factory_occurrence_alpha;
}



