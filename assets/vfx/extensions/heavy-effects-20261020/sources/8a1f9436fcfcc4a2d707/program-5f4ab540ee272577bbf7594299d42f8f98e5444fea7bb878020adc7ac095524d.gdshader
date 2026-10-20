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
render_mode blend_mix, cull_disabled, diffuse_toon, specular_toon;

uniform vec2 Texture_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Disolver_Texture : source_color;
uniform float Light_attenuation = 1.3;
uniform float Shadow_roundness = 1.0;
uniform sampler2D Color_1D_Gradient : source_color, hint_default_black;


void fragment() {
// Input:2
	vec4 n_out2p0 = COLOR;
	float n_out2p4 = n_out2p0.a;


// Vector2Parameter:6
	vec2 n_out6p0 = Texture_Scale;


// UVFunc:5
	vec2 n_in5p2 = vec2(0.00000, 0.00000);
	vec2 n_out5p0 = (UV - n_in5p2) * n_out6p0 + n_in5p2;


	vec4 n_out4p0;
// Texture2D:4
	n_out4p0 = texture(Disolver_Texture, n_out5p0);
	float n_out4p1 = n_out4p0.r;


// Output:0
	ALBEDO = vec3(n_out2p0.xyz);
	ALPHA = n_out4p1;
	ALPHA*=smoothstep(n_out2p4,n_out2p4+.1,n_out4p1);


ALBEDO*=0.45;EMISSION*=0.45;ALPHA*=payload_alpha;

ALBEDO*=0.18;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);

ALPHA*=0.18*(1.0-smoothstep(0.4,0.9,(vfx_package_seconds()+vfx_package_offset_payload_seconds)));
}

void light() {

	float dot_result = dot(NORMAL, LIGHT);
	float add_some_math = (clamp(dot_result, -0.90, 0.90) + 1.0)*0.47*Light_attenuation;
	float fresnel = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), Shadow_roundness);
	float round_cell_shade = clamp(add_some_math,0.04, 0.98) * fresnel;
	vec4 color_1D_gradient = texture(Color_1D_Gradient, vec2(round_cell_shade));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * color_1D_gradient.rgb * ATTENUATION * 0.35;

}


void vertex(){
vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}

