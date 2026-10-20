shader_type spatial;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded, shadows_disabled, fog_disabled;

uniform vec2 Trail_Scale = vec2(3.000000, 2.000000);
uniform vec2 Trail_Speed = vec2(0.100000, 2.000000);
uniform sampler2D Trail_Texture : source_color, repeat_enable;
uniform sampler2D Overlapping_Gradient : source_color, repeat_disable;
uniform sampler2D Gradient__Opacity : source_color, filter_linear;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.
}

void fragment() {
// Vector2Parameter:54
	vec2 n_out54p0 = Trail_Scale;


// UVFunc:53
	vec2 n_in53p2 = vec2(0.00000, 0.00000);
	vec2 n_out53p0 = (UV - n_in53p2) * n_out54p0 + n_in53p2;


// Input:50
	float n_out50p0 = source_clock;


// Vector2Parameter:55
	vec2 n_out55p0 = Trail_Speed;


// VectorOp:51
	vec2 n_out51p0 = vec2(n_out50p0) * n_out55p0;


// UVFunc:52
	vec2 n_in52p1 = vec2(1.00000, 1.00000);
	vec2 n_out52p0 = n_out51p0 * n_in52p1 + n_out53p0;


	vec4 n_out57p0;
// Texture2D:57
	n_out57p0 = texture(Trail_Texture, n_out52p0);
	float n_out57p1 = n_out57p0.r;


	vec4 n_out63p0;
// Texture2D:63
	n_out63p0 = texture(Overlapping_Gradient, vec2(n_out57p1));


	vec4 n_out66p0;
// Texture2D:66
	n_out66p0 = texture(Gradient__Opacity, UV);
	float n_out66p1 = n_out66p0.r;


// FloatOp:58
	float n_out58p0 = n_out57p0.x * n_out66p1;


// Step:64
	float n_in64p0 = 0.10000;
	float n_out64p0 = step(n_in64p0, n_out58p0);


// Output:0
	ALBEDO = vec3(n_out63p0.xyz);
	ALPHA = n_out64p0;


}



