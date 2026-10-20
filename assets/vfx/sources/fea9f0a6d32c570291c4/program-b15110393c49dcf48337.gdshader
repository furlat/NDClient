shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float fresnelpower = 1.0;
uniform sampler2D AddTexture : source_color, hint_default_black, repeat_disable;
instance uniform float BreakFactorLocal : hint_range(0.0, 5.0) = 0.0;
uniform float BreakFactorGlobal : hint_range(0.0, 5.0) = 0.0;
instance uniform vec2 Texture_add2_scale = vec2(1.000000, 1.000000);
uniform vec2 Texture_add2_offset = vec2(2.010000, 0.630000);
uniform sampler2D AddTexture2 : source_color, hint_default_black, repeat_enable;
uniform vec2 Details_scale = vec2(1.000000, 1.000000);
uniform vec2 Details_speed;
uniform sampler2D DetailsTexture : source_color, hint_default_black, repeat_enable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform float ColorIntensity = 1.0;



void fragment() {
// FloatParameter:66
	float n_out66p0 = fresnelpower;


// Fresnel:3
	float n_out3p0 = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out66p0);


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(AddTexture, UV);
	float n_out10p1 = n_out10p0.r;


// FloatOp:8
	float n_out8p0 = n_out3p0 + n_out10p1;


// FloatParameter:69
	float n_out69p0 = BreakFactorLocal;


// FloatParameter:64
	float n_out64p0 = BreakFactorGlobal;


// FloatOp:70
	float n_out70p0 = n_out69p0 + n_out64p0;


// Vector2Parameter:62
	vec2 n_out62p0 = Texture_add2_scale;


// UVFunc:61
	vec2 n_in61p2 = vec2(0.00000, 0.00000);
	vec2 n_out61p0 = (UV - n_in61p2) * n_out62p0 + n_in61p2;


// Vector2Parameter:68
	vec2 n_out68p0 = Texture_add2_offset;


// UVFunc:67
	vec2 n_in67p1 = vec2(1.00000, 1.00000);
	vec2 n_out67p0 = n_out68p0 * n_in67p1 + n_out61p0;


	vec4 n_out59p0;
// Texture2D:59
	n_out59p0 = texture(AddTexture2, n_out67p0);
	float n_out59p1 = n_out59p0.r;


// FloatOp:75
	float n_out75p0 = n_out70p0 * n_out59p1;


// FloatOp:74
	float n_out74p0 = max(n_out8p0, n_out75p0);


// Vector2Parameter:20
	vec2 n_out20p0 = Details_scale;


// UVFunc:16
	vec2 n_in16p2 = vec2(0.00000, 0.00000);
	vec2 n_out16p0 = (UV - n_in16p2) * n_out20p0 + n_in16p2;


// Input:17
	float n_out17p0 = TIME;


// Vector2Parameter:19
	vec2 n_out19p0 = Details_speed;


// VectorOp:18
	vec2 n_out18p0 = vec2(n_out17p0) * n_out19p0;


// UVFunc:15
	vec2 n_in15p1 = vec2(1.00000, 1.00000);
	vec2 n_out15p0 = n_out18p0 * n_in15p1 + n_out16p0;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(DetailsTexture, n_out15p0);
	float n_out11p1 = n_out11p0.r;


// FloatOp:14
	float n_out14p0 = n_out74p0 + n_out11p1;


	vec4 n_out5p0;
// Texture2D:5
	n_out5p0 = texture(Color1DGradient, vec2(n_out14p0));


// FloatParameter:7
	float n_out7p0 = ColorIntensity;


// VectorOp:6
	vec3 n_out6p0 = vec3(n_out5p0.xyz) * vec3(n_out7p0);


// Output:0
	ALBEDO = n_out6p0;



ALPHA *= factory_occurrence_alpha;
}



