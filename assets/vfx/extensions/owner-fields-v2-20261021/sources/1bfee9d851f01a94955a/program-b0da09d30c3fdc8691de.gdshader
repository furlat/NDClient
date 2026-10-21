shader_type spatial;

uniform sampler2D solid_cells:filter_nearest,repeat_disable;
uniform vec2 solid_mask_origin=vec2(0.0);
uniform vec2 solid_mask_size=vec2(1.0);
uniform mat4 solid_world_to_local=mat4(1.0);
uniform vec4 solid_dome_projection=vec4(0.0);
uniform int solid_cut_count=0;
uniform vec4 solid_cuts[64];

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;
uniform float age=0.0;uniform float opacity=1.0;uniform vec2 camera_sign;uniform bool front=false;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx, unshaded;

uniform float fresnelpower = 1;
uniform sampler2D AddTexture : source_color, hint_default_black, repeat_disable;
instance uniform float BreakFactorLocal : hint_range(0, 5) = 0;
uniform float BreakFactorGlobal : hint_range(0, 5) = 0;
instance uniform vec2 Texture_add2_scale = vec2(1.000000, 1.000000);
uniform vec2 Texture_add2_offset = vec2(2.010000, 0.630000);
uniform sampler2D AddTexture2 : source_color, hint_default_black, repeat_enable;
uniform vec2 Details_scale = vec2(1.000000, 1.000000);
uniform vec2 Details_speed;
uniform sampler2D DetailsTexture : source_color, hint_default_black, repeat_enable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;
uniform float ColorIntensity = 1;



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
	float n_out69p0 = 0.0;


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
	float n_out17p0 = 1.5;


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


vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;ALPHA=opacity*(.20+.28*pow(1.0-abs(dot(NORMAL,VIEW)),1.6));
ALPHA *= factory_occurrence_alpha;

vec3 solid_point=(solid_world_to_local*INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
vec2 solid_mask_point=solid_point.xz;
if(solid_dome_projection.w>0.5){
 vec2 solid_radial=solid_mask_point-solid_dome_projection.xy;
 float solid_radius=length(solid_radial);
 if(solid_radius>0.0)solid_mask_point=solid_dome_projection.xy+solid_radial/solid_radius*solid_dome_projection.z;
 else solid_mask_point=solid_dome_projection.xy+vec2(solid_dome_projection.z,0.0);
}
vec2 solid_cell=floor(solid_mask_point/2.121320344+vec2(0.5));
vec2 solid_pixel=solid_cell-solid_mask_origin;
if(any(lessThan(solid_pixel,vec2(0.0)))||any(greaterThanEqual(solid_pixel,solid_mask_size)))discard;
if(texture(solid_cells,(solid_pixel+vec2(0.5))/solid_mask_size).r<0.5)discard;
for(int solid_index=0;solid_index<64;solid_index++){
 if(solid_index>=solid_cut_count)break;
 vec3 solid_delta=solid_point-solid_cuts[solid_index].xyz;
 if(solid_delta.x>0.0&&solid_delta.z>0.0&&solid_delta.y>=0.0&&all(lessThan(solid_delta,vec3(4.242640688))))discard;
}
}



