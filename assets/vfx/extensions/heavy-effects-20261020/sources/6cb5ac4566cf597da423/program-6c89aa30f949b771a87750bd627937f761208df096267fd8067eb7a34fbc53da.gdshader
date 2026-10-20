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

uniform sampler2D fireball_dark:source_color;
uniform sampler2D fireball_hot:source_color;

uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec2 Cloud_Color_Scale = vec2(1.000000, 1.000000);
uniform sampler2D Dark_variation : source_color, filter_linear;
uniform sampler2D Dark_Color_Gradient_1D : source_color, filter_linear;
uniform vec2 Dissapear_scale = vec2(1.000000, 1.000000);
uniform sampler2D Disapear_Noise : source_color, filter_linear, repeat_enable;
uniform vec4 Bright_Color : source_color;
uniform float Color_Intensity : hint_range(0.0, 1.0);
uniform float Color_max;
uniform vec2 Noise_color_scale = vec2(1.000000, 1.000000);
uniform sampler2D Noise_Color : source_color;



void fragment() {
// Vector2Parameter:50
	vec2 n_out50p0 = Cloud_Color_Scale;


// UVFunc:49
	vec2 n_in49p2 = vec2(0.00000, 0.00000);
	vec2 n_out49p0 = (UV - n_in49p2) * n_out50p0 + n_in49p2;


	vec4 n_out43p0;
// Texture2D:43
	n_out43p0 = texture(Dark_variation, n_out49p0);
	float n_out43p1 = n_out43p0.r;


	vec4 n_out45p0;
// Texture2D:45
	n_out45p0 = texture(Dark_Color_Gradient_1D, vec2(n_out43p1));


// Vector2Parameter:51
	vec2 n_out51p0 = Dissapear_scale;


// UVFunc:52
	vec2 n_in52p2 = vec2(0.00000, 0.00000);
	vec2 n_out52p0 = (UV - n_in52p2) * n_out51p0 + n_in52p2;


	vec4 n_out38p0;
// Texture2D:38
	n_out38p0 = texture(Disapear_Noise, n_out52p0);
	float n_out38p1 = n_out38p0.r;


// ColorParameter:3
	vec4 n_out3p0 = Bright_Color;


// FloatParameter:15
	float n_out15p0 = Color_Intensity;


// FloatParameter:35
	float n_out35p0 = Color_max;


	float n_out34p0;
// Remap:34
	float n_in34p1 = 0.00000;
	float n_in34p2 = 1.00000;
	float n_in34p3 = 0.00000;
	{
		float __input_range = n_in34p2 - n_in34p1;
		float __output_range = n_out35p0 - n_in34p3;
		n_out34p0 = n_in34p3 + __output_range * ((n_out15p0 - n_in34p1) / __input_range);
	}


// VectorOp:14
	vec3 n_out14p0 = vec3(n_out3p0.xyz) * vec3(n_out34p0);


// Input:36
	vec4 n_out36p0 = COLOR;
	float n_out36p1 = n_out36p0.r;


// Vector2Parameter:53
	vec2 n_out53p0 = Noise_color_scale;


// UVFunc:54
	vec2 n_in54p2 = vec2(0.00000, 0.00000);
	vec2 n_out54p0 = (UV - n_in54p2) * n_out53p0 + n_in54p2;


	vec4 n_out9p0;
// Texture2D:9
	n_out9p0 = texture(Noise_Color, n_out54p0);
	float n_out9p1 = n_out9p0.r;


// SmoothStep:10
	float n_in10p1 = 1.00000;
	float n_out10p0 = smoothstep(n_out36p1, n_in10p1, n_out9p1);


// VectorOp:13
	vec4 n_out13p0 = vec4(n_out14p0, 0.0) * vec4(n_out10p0);


// Input:33
	vec4 n_out33p0 = COLOR;
	float n_out33p4 = n_out33p0.a;


// Output:0
	ALBEDO = vec3(n_out45p0.xyz);
	ALPHA = n_out38p1;
	EMISSION = vec3(n_out13p0.xyz);
	ALPHA*=smoothstep(n_out33p4,n_out33p4+.07,ALPHA);



ALBEDO*=0.45;EMISSION*=0.45;ALPHA*=payload_alpha;

float heat=clamp(COLOR.r*0.9+n_out9p1*0.28,0.0,1.0);ALBEDO=texture(fireball_dark,vec2(heat)).rgb*0.4;EMISSION=texture(fireball_hot,vec2(heat)).rgb*0.12;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);

ALPHA*=0.5;
}


void vertex(){
vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}

