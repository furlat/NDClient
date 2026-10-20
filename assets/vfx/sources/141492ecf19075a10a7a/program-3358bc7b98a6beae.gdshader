shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_movement_clock=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float movement_clock=0.0;
uniform float movement_fade=1.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_toon;

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
// Input:3
	vec4 n_out3p0 = COLOR;
	float n_out3p1 = n_out3p0.r;
	float n_out3p2 = n_out3p0.g;


// VectorCompose:7
	vec3 n_out7p0 = vec3(n_out3p2, n_out3p1, n_out3p2);


// Input:2
	vec3 n_out2p0 = VERTEX;


// VectorOp:4
	vec3 n_out4p0 = n_out7p0 * n_out2p0;


// Output:0
	VERTEX = n_out4p0;


}

void fragment() {
vec3 world_pos=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;


// Vector2Parameter:41
	vec2 n_out41p0 = speed;


// Input:37
	vec4 n_out37p0 = COLOR;
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
	vec4 n_out35p0 = COLOR;
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
	vec4 n_out36p0 = COLOR;
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



ALPHA *= movement_fade;
}


