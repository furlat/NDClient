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
render_mode blend_mix, depth_draw_never, depth_test_default, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Scale = vec2(1.000000, 1.000000);
uniform vec2 Speed;
uniform sampler2D Texture : source_color, repeat_enable;
uniform sampler2D Texture_Substract : source_color, repeat_disable;
uniform float Opacity : hint_range(0.0, 1.0) = 0.0;
uniform bool Use_Fresnel = false;
uniform bool Fresnel_Invert;
uniform float Fresnel_Power = 1.0;
uniform float Roughness : hint_range(0.0, 1.0) = 1.0;
uniform float Specular : hint_range(0.0, 1.0) = 0.5;



void vertex() {
// GetBillboardMatrix:2
	// Node is disabled and code is not generated.

vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}

void fragment() {
// Input:4
	vec4 n_out4p0 = COLOR;
	float n_out4p4 = n_out4p0.a;


// Vector2Parameter:16
	vec2 n_out16p0 = Scale;


// UVFunc:15
	vec2 n_in15p2 = vec2(0.00000, 0.00000);
	vec2 n_out15p0 = (UV - n_in15p2) * n_out16p0 + n_in15p2;


// Vector2Parameter:21
	vec2 n_out21p0 = Speed;


// Input:24
	float n_out24p0 = (vfx_package_seconds()+vfx_package_offset_payload_seconds);


// VectorOp:25
	vec2 n_out25p0 = n_out21p0 * vec2(n_out24p0);


// UVFunc:26
	vec2 n_in26p1 = vec2(1.00000, 1.00000);
	vec2 n_out26p0 = n_out25p0 * n_in26p1 + n_out15p0;


	vec4 n_out10p0;
// Texture2D:10
	n_out10p0 = texture(Texture, n_out26p0);
	float n_out10p1 = n_out10p0.r;


	vec4 n_out19p0;
// Texture2D:19
	n_out19p0 = texture(Texture_Substract, UV);
	float n_out19p1 = n_out19p0.r;


// FloatOp:18
	float n_out18p0 = n_out10p1 - n_out19p1;


// Clamp:23
	float n_in23p1 = 0.00000;
	float n_in23p2 = 1.00000;
	float n_out23p0 = clamp(n_out18p0, n_in23p1, n_in23p2);


// SmoothStep:17
	float n_in17p1 = 1.00000;
	float n_out17p0 = smoothstep(n_out4p4, n_in17p1, n_out23p0);


// FloatParameter:28
	float n_out28p0 = Opacity;


// FloatOp:27
	float n_out27p0 = n_out17p0 * n_out28p0;


// BooleanParameter:34
	bool n_out34p0 = Use_Fresnel;


// BooleanParameter:32
	bool n_out32p0 = Fresnel_Invert;


// FloatParameter:31
	float n_out31p0 = Fresnel_Power;


// Fresnel:29
	float n_out29p0 = n_out32p0 ? (pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0)) : (pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), n_out31p0));


	float n_out33p0;
// Switch:33
	float n_in33p2 = 1.00000;
	n_out33p0 = mix(n_in33p2, n_out29p0, float(n_out34p0));


// FloatOp:30
	float n_out30p0 = n_out27p0 * n_out33p0;


// FloatParameter:36
	float n_out36p0 = Roughness;


// FloatParameter:35
	float n_out35p0 = Specular;


// Output:0
	ALBEDO = vec3(n_out4p0.xyz);
	ALPHA = n_out30p0;
	ROUGHNESS = n_out36p0;
	SPECULAR = n_out35p0;



ALBEDO*=0.7;EMISSION*=0.7;ALPHA*=payload_alpha;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);

EMISSION+=ALBEDO*.24;
}


