shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_payload_seconds=0.0;

varying vec3 payload_actual_world;
uniform vec3 payload_footprint_origin=vec3(0.0);
uniform vec2 payload_cells[128];
uniform vec4 payload_open_edges[128];
uniform int payload_cell_count=0;
float payload_membership(vec2 point){
 float coverage=0.0;
 for(int i=0;i<128;i++){
  if(i>=payload_cell_count)break;
  vec2 relative=point-payload_cells[i];vec2 distance=abs(relative);vec4 edges=payload_open_edges[i];
  float edge_x=relative.x<0.0?edges.x:edges.y;float edge_y=relative.y<0.0?edges.z:edges.w;
  float inside=1.0-step(0.50001,max(distance.x,distance.y));
  float soft_x=mix(1.0,smoothstep(0.015,0.13,0.5-distance.x),edge_x);
  float soft_y=mix(1.0,smoothstep(0.015,0.13,0.5-distance.y),edge_y);
  vec2 corner=max(distance-vec2(0.25),vec2(0.0));float rounding=1.0-smoothstep(0.20,0.25,length(corner));
  coverage=max(coverage,inside*soft_x*soft_y*mix(1.0,rounding,edge_x*edge_y));
 }
 return coverage;
}

uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed_XY;
uniform sampler2D Disolver_Texture : source_color, repeat_enable;
uniform sampler2D Color_1D_Gradient : source_color, repeat_disable;
uniform sampler2D Metallic_Texture : source_color, repeat_disable;
uniform sampler2D Texture_Roughtness : source_color, repeat_enable;
uniform sampler2D Roughtness_1D_Gradient : source_color, repeat_disable;
uniform float Specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D Normal_Texture : hint_normal, repeat_enable;
uniform float Normal_Map_Depth = 1.0;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.

vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}

void fragment() {
// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed_XY;


// Input:31
	float n_out31p0 = (vfx_package_seconds()+vfx_package_offset_payload_seconds);


// VectorOp:32
	vec2 n_out32p0 = n_out21p0 * vec2(n_out31p0);


// UVFunc:20
	vec2 n_in20p1 = vec2(1.00000, 1.00000);
	vec2 n_out20p0 = n_out32p0 * n_in20p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Disolver_Texture, n_out20p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out30p0;
// Texture2D:30
	n_out30p0 = texture(Color_1D_Gradient, vec2(n_out10p1));


// Input:36
	vec4 n_out36p0 = COLOR;


// VectorOp:35
	vec3 n_out35p0 = vec3(n_out30p0.xyz) * vec3(n_out36p0.xyz);


// Reroute:28
	vec2 n_out28p0 = n_out20p0;


	vec4 n_out26p0;
// Texture2D:26
	n_out26p0 = texture(Metallic_Texture, n_out28p0);
	float n_out26p1 = n_out26p0.r;


	vec4 n_out25p0;
// Texture2D:25
	n_out25p0 = texture(Texture_Roughtness, n_out28p0);
	float n_out25p1 = n_out25p0.r;


	vec4 n_out34p0;
// Texture2D:34
	n_out34p0 = texture(Roughtness_1D_Gradient, vec2(n_out25p1));
	float n_out34p1 = n_out34p0.r;


// FloatParameter:38
	float n_out38p0 = Specular;


	vec4 n_out23p0;
// Texture2D:23
	n_out23p0 = texture(Normal_Texture, n_out28p0);


// FloatParameter:37
	float n_out37p0 = Normal_Map_Depth;


// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// Output:0
	ALBEDO = n_out35p0;
	ALPHA = n_out10p1;
	METALLIC = n_out26p1;
	ROUGHNESS = n_out34p1;
	SPECULAR = n_out38p0;
	NORMAL_MAP = vec3(n_out23p0.xyz);
	NORMAL_MAP_DEPTH = n_out37p0;
	ALPHA*=smoothstep(n_out4p4,n_out4p4+.09,n_out10p1);



ALBEDO*=0.7;EMISSION*=0.7;ALPHA*=payload_alpha;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);

EMISSION+=ALBEDO*.24;
}


