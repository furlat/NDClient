shader_type spatial;
uniform float vfx_clock=0.0;uniform float opacity=0.0;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Trail_Speed;
uniform sampler2D Texture2DParameter : source_color, filter_linear;



void fragment() {
// Input:12
	vec4 n_out12p0 = COLOR;
	float n_out12p4 = n_out12p0.a;


// Vector2Parameter:11
	vec2 n_out11p0 = Scale;


// UVFunc:10
	vec2 n_in10p2 = vec2(0.00000, 0.00000);
	vec2 n_out10p0 = (UV - n_in10p2) * n_out11p0 + n_in10p2;


// Input:4
	float n_out4p0 = vfx_clock;


// Vector2Parameter:6
	vec2 n_out6p0 = Trail_Speed;


// VectorOp:5
	vec2 n_out5p0 = vec2(n_out4p0) * n_out6p0;


// UVFunc:3
	vec2 n_in3p1 = vec2(1.00000, 1.00000);
	vec2 n_out3p0 = n_out5p0 * n_in3p1 + n_out10p0;


	vec4 n_out14p0;
// Texture2D:14
	n_out14p0 = texture(Texture2DParameter, n_out3p0);
	float n_out14p1 = n_out14p0.r;


// FloatOp:9
	float n_out9p0 = n_out12p4 * n_out14p1;


// Output:0
	ALBEDO = mix(vec3(.18,.65,.24),vec3(.80,1.5,.89),n_out14p1);
	ALPHA = (.55+.45*n_out14p1) * opacity * pow(max(0.0,1.0-abs(UV.y-.5)*2.0),1.2);


}
