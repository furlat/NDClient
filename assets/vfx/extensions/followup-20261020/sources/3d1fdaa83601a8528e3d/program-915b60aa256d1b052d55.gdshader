shader_type spatial;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_toon, specular_schlick_ggx;

uniform vec2 VertexScale = vec2(1.000000, 1.000000);
uniform vec2 VertexSpeed = vec2(0.000000, 0.000000);
uniform sampler2D TextureVertex : source_color, hint_default_black, repeat_enable;
uniform sampler2D TextureVertexMask : source_color, repeat_enable;
uniform float VertexIntensity = 0.30000001192093;
uniform vec2 BaseScale = vec2(1.000000, 1.000000);
uniform vec2 BaseScaleSynamic = vec2(0.000000, 0.000000);
uniform vec2 BaseVelocity = vec2(0.000000, 0.000000);
uniform sampler2D BaseTexture : source_color;
uniform vec4 Color : source_color = vec4(1.000000, 1.000000, 1.000000, 1.000000);
uniform float Opacity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D Roughtness : source_color;
uniform float Specular = 1.0;
uniform float AmbientLight : hint_range(0.0, 10.0) = 0.20000000298023;
uniform bool InvertFresnel = false;
uniform float AmbientFresnelLightPower = 1.0;
uniform sampler2D NormalTexture : hint_normal;
uniform float NormalIntensity = 0.0;
uniform float Anisotropy : hint_range(0.0, 1.0);
uniform float AlphaScissor : hint_range(-0.10000000149012, 1.10000002384186) = 0.32100000977516;



void vertex() {
// Input:5
	vec3 n_out5p0 = VERTEX;


// Vector2Parameter:11
	vec2 n_out11p0 = VertexScale;


// UVFunc:12
	vec2 n_in12p2 = vec2(0.00000, 0.00000);
	vec2 n_out12p0 = (UV - n_in12p2) * n_out11p0 + n_in12p2;


// Vector2Parameter:10
	vec2 n_out10p0 = VertexSpeed;


// Input:3
	float n_out3p0 = source_clock;


// VectorOp:9
	vec2 n_out9p0 = n_out10p0 * vec2(n_out3p0);


// UVFunc:2
	vec2 n_in2p1 = vec2(1.00000, 1.00000);
	vec2 n_out2p0 = n_out9p0 * n_in2p1 + n_out12p0;


	vec4 n_out8p0;
// Texture2D:8
	n_out8p0 = texture(TextureVertex, n_out2p0);
	float n_out8p1 = n_out8p0.r;


	vec4 n_out17p0;
// Texture2D:17
	n_out17p0 = texture(TextureVertexMask, UV);
	float n_out17p1 = n_out17p0.r;


// FloatOp:18
	float n_out18p0 = n_out8p1 * n_out17p1;


// FloatParameter:15
	float n_out15p0 = VertexIntensity;


// FloatOp:13
	float n_out13p0 = n_out18p0 * n_out15p0;


// Input:14
	vec3 n_out14p0 = NORMAL;


// VectorOp:4
	vec3 n_out4p0 = vec3(n_out13p0) * n_out14p0;


// VectorOp:6
	vec3 n_out6p0 = n_out5p0 + n_out4p0;


// Output:0
	VERTEX = n_out6p0;


}

void fragment() {
// Vector2Parameter:7
	vec2 n_out7p0 = BaseScale;


// Vector2Parameter:33
	vec2 n_out33p0 = BaseScaleSynamic;


// Input:32
	vec4 n_out32p0 = COLOR;
	float n_out32p4 = n_out32p0.a;


// VectorOp:34
	vec2 n_out34p0 = n_out33p0 * vec2(n_out32p4);


// VectorOp:35
	vec2 n_out35p0 = n_out7p0 + n_out34p0;


// UVFunc:6
	vec2 n_in6p2 = vec2(0.00000, 0.00000);
	vec2 n_out6p0 = (UV - n_in6p2) * n_out35p0 + n_in6p2;


// Vector2Parameter:8
	vec2 n_out8p0 = BaseVelocity;


// Input:10
	float n_out10p0 = source_clock;


// VectorOp:9
	vec2 n_out9p0 = n_out8p0 * vec2(n_out10p0);


// UVFunc:5
	vec2 n_in5p1 = vec2(1.00000, 1.00000);
	vec2 n_out5p0 = n_out9p0 * n_in5p1 + n_out6p0;


	vec4 n_out4p0;
// Texture2D:4
	n_out4p0 = texture(BaseTexture, n_out5p0);


// ColorParameter:29
	vec4 n_out29p0 = Color;


// VectorOp:28
	vec4 n_out28p0 = n_out4p0 * n_out29p0;
	float n_out28p4 = n_out28p0.a;


// FloatParameter:19
	float n_out19p0 = Opacity;


// FloatOp:18
	float n_out18p0 = n_out28p4 * n_out19p0;


	vec4 n_out13p0;
// Texture2D:13
	n_out13p0 = texture(Roughtness, n_out5p0);
	float n_out13p1 = n_out13p0.r;


// FloatParameter:11
	float n_out11p0 = Specular;


// FloatParameter:21
	float n_out21p0 = AmbientLight;


// BooleanParameter:36
	bool n_out36p0 = InvertFresnel;


// FloatParameter:24
	float n_out24p0 = AmbientFresnelLightPower;


// Fresnel:23
	float n_out23p0 = n_out36p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out24p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out24p0));


// FloatOp:22
	float n_out22p0 = n_out21p0 * n_out23p0;


// VectorOp:20
	vec3 n_out20p0 = vec3(n_out28p0.xyz) * vec3(n_out22p0);


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(NormalTexture, n_out5p0);


// FloatParameter:16
	float n_out16p0 = NormalIntensity;


// FloatParameter:17
	float n_out17p0 = Anisotropy;


// FloatParameter:2
	float n_out2p0 = AlphaScissor;


// Input:31
	vec4 n_out31p0 = COLOR;
	float n_out31p4 = n_out31p0.a;


// FloatOp:30
	float n_out30p0 = n_out2p0 * n_out31p4;


// Output:0
	ALBEDO = vec3(n_out28p0.xyz);
	ALPHA = n_out18p0;
	ROUGHNESS = n_out13p1;
	SPECULAR = n_out11p0;
	EMISSION = n_out20p0;
	NORMAL_MAP = vec3(n_out15p0.xyz);
	NORMAL_MAP_DEPTH = n_out16p0;
	ANISOTROPY = n_out17p0;
	ALPHA_SCISSOR_THRESHOLD = n_out30p0;


}



