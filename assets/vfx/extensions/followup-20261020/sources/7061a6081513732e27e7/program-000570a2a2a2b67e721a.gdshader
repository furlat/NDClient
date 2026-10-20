shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0); uniform float contact_column_alpha=1.0;
uniform float source_clock=0.0;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded, fog_disabled;

uniform sampler2D Alpha_Texture : source_color;



void vertex() {
	mat4 n_out2p0;
// GetBillboardMatrix:2
	{
		mat4 __mvm = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
		__mvm = __mvm * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		n_out2p0 = __mvm;
	}


// Output:0
	MODELVIEW_MATRIX = n_out2p0;


}

void fragment() {
vec3 split_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
if (split_world.y < max(0.0,22.5*(0.65-source_clock)/(0.65-0.433333))) discard;

// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


	vec4 n_out3p0;
// Texture2D:3
	n_out3p0 = texture(Alpha_Texture, UV);
	float n_out3p1 = n_out3p0.r;


// FloatOp:5
	float n_out5p0 = n_out4p4 * n_out3p1;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out5p0;



ALPHA *= contact_column_alpha;
}


