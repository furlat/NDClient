shader_type spatial;
uniform float ward_seconds=0.0;
uniform float ward_alpha=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float Color_Intensity = 1.0;
uniform sampler2D Alpha_Texture : source_color, repeat_enable;
uniform sampler2D Color_1D_gradient : source_color, repeat_disable;
uniform sampler2D Texture_Disolver : source_color, repeat_disable;
uniform float Vanishing : hint_range(0.05000000074506, 1.0) = 1.0;



void fragment() {
// FloatParameter:12
	float n_out12p0 = Color_Intensity;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Alpha_Texture, UV);
	float n_out3p1 = n_out3p0.r;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Color_1D_gradient, vec2(n_out3p1));
	float n_out11p4 = n_out11p0.a;


// VectorOp:13
	vec3 n_out13p0 = vec3(n_out12p0) * vec3(n_out11p0.xyz);


	vec4 n_out15p0;
// Texture2D:15
	n_out15p0 = texture(Texture_Disolver, UV);
	float n_out15p1 = n_out15p0.r;


// FloatOp:18
	float n_out18p0 = n_out11p4 * n_out15p1;


// FloatParameter:6
	float n_out6p0 = Vanishing;


// Output:0
	ALBEDO = n_out13p0;
	ALPHA = n_out18p0;
	ALPHA*=smoothstep(n_out6p0,n_out6p0+0.08,n_out18p0);



ALBEDO*=0.16;
EMISSION*=0.16;
ALPHA*=ward_alpha;

ALBEDO=vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722)));
}


