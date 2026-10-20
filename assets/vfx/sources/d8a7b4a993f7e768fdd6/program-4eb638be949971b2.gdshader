shader_type spatial;
uniform float ward_seconds=0.0;
uniform float ward_alpha=0.0;
uniform vec3 cone_origin=vec3(0.0);
uniform vec3 cone_forward=vec3(0.0,0.0,-1.0);
uniform float cone_length=3.0;
varying vec3 cone_world;
render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform sampler2D Base_noise2 : source_color, repeat_enable;
uniform vec2 Speed_XY2;
uniform vec2 Scale_XY2 = vec2(1.000000, 1.000000);
uniform sampler2D Texture_add : source_color, hint_default_black, repeat_disable;
uniform sampler2D Texture_substract : source_color, repeat_disable;
uniform sampler2D Gradient_Color_1D2 : source_color, repeat_disable;
uniform float Color_Intensity2 = 1.0;
uniform float Fill : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D tex_frg_58 : source_color;



void fragment() {
// Vector2Parameter:43
	vec2 n_out43p0 = Scale_XY2;


// UVFunc:39
	vec2 n_in39p2 = vec2(0.00000, 0.00000);
	vec2 n_out39p0 = (UV - n_in39p2) * n_out43p0 + n_in39p2;


// Vector2Parameter:41
	vec2 n_out41p0 = Speed_XY2;


// Input:40
	float n_out40p0 = ward_seconds;


// VectorOp:42
	vec2 n_out42p0 = n_out41p0 * vec2(n_out40p0);


// UVFunc:38
	vec2 n_in38p1 = vec2(1.00000, 1.00000);
	vec2 n_out38p0 = n_out42p0 * n_in38p1 + n_out39p0;


	vec4 n_out33p0;
// Texture2D:33
	n_out33p0 = texture(Base_noise2, n_out38p0);
	float n_out33p1 = n_out33p0.r;


	vec4 n_out35p0;
// Texture2D:35
	n_out35p0 = texture(Texture_add, UV);
	float n_out35p1 = n_out35p0.r;


// FloatOp:44
	float n_out44p0 = n_out33p1 + n_out35p1;


	vec4 n_out36p0;
// Texture2D:36
	n_out36p0 = texture(Texture_substract, UV);
	float n_out36p1 = n_out36p0.r;


// FloatOp:45
	float n_out45p0 = n_out44p0 - n_out36p1;


// Clamp:57
	float n_in57p1 = 0.00000;
	float n_in57p2 = 1.00000;
	float n_out57p0 = clamp(n_out45p0, n_in57p1, n_in57p2);


	vec4 n_out48p0;
// Texture2D:48
	n_out48p0 = texture(Gradient_Color_1D2, vec2(n_out57p0));
	float n_out48p4 = n_out48p0.a;


// FloatParameter:50
	float n_out50p0 = Color_Intensity2;


// VectorOp:49
	vec3 n_out49p0 = vec3(n_out48p0.xyz) * vec3(n_out50p0);


// FloatParameter:60
	float n_out60p0 = Fill;


// Texture2D:58
	vec4 n_out58p0 = texture(tex_frg_58, UV);
	float n_out58p1 = n_out58p0.r;


// FloatOp:65
	float n_out65p0 = n_out60p0 - n_out58p1;


// Clamp:66
	float n_in66p1 = 0.00000;
	float n_in66p2 = 1.00000;
	float n_out66p0 = clamp(n_out65p0, n_in66p1, n_in66p2);


// FloatOp:63
	float n_out63p0 = n_out48p4 * n_out66p0;


// Output:0
	ALBEDO = n_out49p0;
	ALPHA = n_out63p0;



ALBEDO*=0.11;
EMISSION*=0.11;
ALPHA*=ward_alpha;

   vec3 relative=cone_world-cone_origin;
   float along=dot(relative,cone_forward);
   float across=length(relative-cone_forward*along);
   float width=max(0.04,along*0.5);
   float end_cover=1.0-smoothstep(cone_length-0.22,cone_length,along);
   float side_cover=1.0-smoothstep(max(0.0,width-0.10),width,across);
   ALPHA*=smoothstep(-0.02,0.025,along)*end_cover*side_cover;
  }


void vertex(){
vec4 actual_cone_world4=MODEL_MATRIX*vec4(VERTEX,1.0);cone_world=actual_cone_world4.xyz;
}

