shader_type spatial;
varying float repair_mesh_height;
uniform sampler2D repair_native_noise : source_color;
uniform vec2 repair_native_scale=vec2(3.0);
uniform vec2 repair_native_speed=vec2(0.0,3.0);

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;
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



repair_mesh_height=VERTEX.y;
}

void fragment() {

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



ALPHA *= support_envelope;

float repair_noise=texture(repair_native_noise,UV*repair_native_scale+repair_native_speed*support_clock).r;
float repair_tip=1.0-smoothstep(0.74+0.22*repair_noise,0.995,repair_mesh_height);
ALPHA*=0.35*repair_tip;
}




