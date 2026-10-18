shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;

uniform float glyph_clock=0.;
uniform float Color_Intensity = 1;
uniform sampler2D Alpha_Texture : source_color, repeat_enable;
uniform sampler2D Color_1D_gradient : source_color, repeat_disable;
uniform sampler2D Texture_Disolver : source_color, repeat_disable;
uniform float Vanishing : hint_range(0.05000000074506, 1) = 1;



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
	ALPHA_SCISSOR_THRESHOLD = .012; ALBEDO *= .86 + .14*sin(UV.x*8.0-UV.y*5.0+glyph_clock*3.14159265);


}
