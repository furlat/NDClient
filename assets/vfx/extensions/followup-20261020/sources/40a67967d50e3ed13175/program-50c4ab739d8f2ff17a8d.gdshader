shader_type spatial;uniform float gpu_legacy_present=0.;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
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



uniform bool gpu_legacy_tube = false;
uniform bool gpu_legacy_animal = false;
uniform int gpu_legacy_piece = 0;
uniform float gpu_legacy_seconds = 0.;

vec3 gpu_legacy_point(int station) {
	float index = float(gpu_legacy_piece);
	float seconds = gpu_legacy_seconds;
	float along = float(station) / 64.;
	float phase = seconds * 6.28318530718 / 4. + index * 2.13;
	float settled = smoothstep(.7, 1.5, seconds);
	float angle = phase + along * 6.28318530718 * mix(.72, gpu_legacy_piece == 0 ? .24 : .14, settled);
	float radius = mix(.68, .55, settled) + .06 * sin(along * 6.28318530718 * 2. + phase);
	float height = mix(.20 + 2.2 * along, (gpu_legacy_animal ? 2.35 : 1.1) + .35 * along + index * .12, settled) + .06 * sin(angle * 2. + index);
	return vec3(cos(angle) * radius, height, sin(angle) * radius);
}

vec3 gpu_legacy_position(vec3 point) {
	float index = float(gpu_legacy_piece);
	float seconds = gpu_legacy_seconds;
	if (!gpu_legacy_tube) {
		float along = point.x / 32.;
		float angle = index * 2.15 + seconds * (1.15 + .12 * index) + along * (1.8 + index * .15);
		float radius = .79 + .15 * sin(along * 3.14159265359 + seconds * 1.3 + index);
		float height = .36 + index * .30 + along * .35 + .12 * sin(seconds * 1.7 + along * 3. + index);
		float width = (.16 + index * .025) * pow(max(0., sin(along * 3.14159265359)), .6);
		point = vec3(cos(angle) * radius, height + point.y * width, sin(angle) * radius);
		return point;
	}
	int station = int(point.x + .5);
	int corner = int(point.y + .5);
	float face = point.z;
	vec3 heading = normalize(gpu_legacy_point(station + 1) - gpu_legacy_point(station));
	vec3 side = cross(heading, vec3(0., 1., 0.));
	if (length(side) < .01) side = cross(heading, vec3(1., 0., 0.));
	side = normalize(side);
	vec3 other = normalize(cross(heading, side));
	float angle = (face + float(corner >= 2)) * 6.28318530718 / 6.;
	float settled = smoothstep(.7, 1.5, seconds);
	float radius = gpu_legacy_animal ? mix(.045, .035, settled) : mix(.065, .043, settled);
	return gpu_legacy_point(station + int(corner == 1 || corner == 2)) + radius * (side * cos(angle) + other * sin(angle));
}

void gpu_directed_vertex(inout vec3 point, inout vec3 normal, inout vec3 tangent, inout vec3 binormal) {
	point = gpu_legacy_position(point);
	}

void gpu_legacy_vertex(inout vec3 point,inout vec3 normal,inout vec3 tangent,inout vec3 binormal,vec3 second_descriptor,vec3 third_descriptor) {
	point = gpu_legacy_position(point);
	vec3 second = gpu_legacy_position(second_descriptor);
	vec3 third = gpu_legacy_position(third_descriptor);
	// SurfaceTool.generate_normals() uses Godot's clockwise triangle normal.
	normal = normalize(cross(third - point, second - point));
}

void vertex() {gpu_legacy_vertex(VERTEX,NORMAL,TANGENT,BINORMAL,CUSTOM0.xyz,CUSTOM1.xyz);
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



ALPHA *= support_envelope;

ALPHA*=gpu_legacy_present;
}




