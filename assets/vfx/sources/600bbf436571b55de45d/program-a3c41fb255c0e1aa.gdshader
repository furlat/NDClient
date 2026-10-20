shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

uniform float psychic_clock=0.0;
uniform float psychic_envelope=0.0;
uniform float psychic_opacity=1.0;
uniform vec4 psychic_tint:source_color=vec4(1.0);

render_mode blend_mix, depth_draw_opaque, depth_test_default, cull_disabled, unshaded;

uniform float scroll_offset : hint_range(-2.0, 0.0) = 0.0;
uniform vec2 speed = vec2(0.000000, 1.000000);
uniform vec2 scale = vec2(1.000000, 1.000000);
uniform sampler2D BaseTexture : source_color, repeat_disable;
uniform vec2 wind_speed = vec2(0.000000, -1.000000);
uniform vec2 wind_scale = vec2(1.000000, 1.000000);
uniform sampler2D Wind_1_texture : source_color, repeat_enable;
uniform vec2 wind_2_speed = vec2(0.000000, 1.200000);
uniform vec2 wind_2_scale = vec2(1.000000, 1.000000);
uniform sampler2D Wind_2_texture_subs : source_color, hint_default_black, repeat_enable;
uniform sampler2D Multiply_Mask : source_color, repeat_disable;
uniform sampler2D Color1DGradient : source_color, repeat_disable;



uniform int gpu_head_shape=0;
uniform int gpu_head_mode=0;
uniform float gpu_head_seconds=0.;
uniform float gpu_head_width=.025;
uniform float gpu_head_intensity=1.;
uniform vec3 gpu_head_heading;
uniform vec3 gpu_head_side;
uniform vec3 gpu_head_left;
uniform vec3 gpu_head_right;
uniform vec3 gpu_head_left_normal;
uniform vec3 gpu_head_right_normal;
uniform vec3 gpu_head_hand;
uniform sampler2D gpu_head_stations : filter_nearest, repeat_disable;
uniform bool gpu_head_source_stations=false;
uniform int gpu_head_count=1;
instance uniform int gpu_head_number=0;
instance uniform int gpu_head_layer=0;
vec4 gpu_head_station(int station) {
 return texelFetch(gpu_head_stations,ivec2(station,gpu_head_layer*gpu_head_count+gpu_head_number),0);
}
vec3 gpu_head_point(int station) {
 if(gpu_head_source_stations)return gpu_head_station(station).xyz;
 float u=float(station)/32.;float t=gpu_head_seconds;float number=float(gpu_head_number);
 float sign_value=gpu_head_number%2==0 ? -1.:1.;
 vec3 normal=sign_value<0.?gpu_head_left_normal:gpu_head_right_normal;
 vec3 anchor=sign_value<0.?gpu_head_left:gpu_head_right;
 if(gpu_head_mode==1)anchor=gpu_head_hand+gpu_head_heading*.055;
 vec3 point;
 if(gpu_head_shape==0){
  float pulse=sin(t*3.-u*6.28318530718+number);
  point=anchor+gpu_head_side*sign_value*(.028+.018*sin(u*3.14159265359)+.008*pulse);
  point+=gpu_head_heading*((u-.5)*.17+float(gpu_head_number/2)*.026);
  point+=vec3(0.,.038*sin(u*6.28318530718+.35*sign_value)+.006*pulse,0.);
  point+=normal*(.012*sin(u*3.14159265359)+.006*sin(t*2.+u*3.14159265359+number));
 }else{
  float angle=mix(-1.2,1.2,u)+.12*sin(t*3.+number);
  float r=.11+float(gpu_head_number/2)*.045;
  point=anchor+gpu_head_side*sign_value*(.025+r*(1.-cos(angle)));
  point+=vec3(0.,sin(angle)*r,0.)+gpu_head_heading*(.05*sin(u*3.14159265359+t*1.4+number));
 }
 if(gpu_head_mode==1)point=anchor+gpu_head_heading*(u*.16)+gpu_head_side*((u-.5)*.06)+vec3(0.,.035*sin(u*3.14159265359+number),0.);
 else if(gpu_head_mode==2)point+=normal*(.10*smoothstep(0.,.3,t));
 return point;
}
void gpu_directed_vertex(inout vec3 vertex,inout vec3 normal,inout vec3 tangent,inout vec3 binormal) {
 int station=int(vertex.x+.5);float edge=vertex.y;float fin=vertex.z;
 vec3 before=gpu_head_point(max(0,station-1));vec3 after=gpu_head_point(min(32,station+1));
 vec3 direction=length(after-before)<.000001?vec3(0.,0.,-1.):normalize(after-before);
 vec3 reference=abs(dot(direction,vec3(0.,1.,0.)))>.99?vec3(1.,0.,0.):vec3(0.,1.,0.);
 vec3 base=normalize(cross(direction,reference));float angle=fin*6.28318530718/3.;
 vec3 side=base*cos(angle)+cross(direction,base)*sin(angle)+direction*dot(direction,base)*(1.-cos(angle));
 float u=float(station)/32.;
 float width=gpu_head_width*pow(max(0.,sin(u*3.14159265359)),.75)*gpu_head_intensity*(1.+.12*sin(gpu_head_seconds*4.-u*6.28318530718+float(gpu_head_number)))*(1.+float(gpu_head_layer)*.25);
 if(gpu_head_source_stations)width=gpu_head_station(station).a;
 vertex=gpu_head_point(station)+side*width*edge;normal=normalize(cross(side,direction));
}

void vertex() {gpu_directed_vertex(VERTEX,NORMAL,TANGENT,BINORMAL);}
void fragment() {
// Vector2Parameter:41
	vec2 n_out41p0 = speed;


// Input:37
	vec4 n_out37p0 = COLOR;
	float n_out37p4 = n_out37p0.a;


// FloatParameter:47
	float n_out47p0 = scroll_offset;


// FloatOp:48
	float n_out48p0 = n_out37p4 + n_out47p0;


// VectorOp:42
	vec2 n_out42p0 = n_out41p0 * vec2(n_out48p0);


// UVFunc:7
	vec2 n_in7p1 = vec2(1.00000, 1.00000);
	vec2 n_out7p0 = n_out42p0 * n_in7p1 + UV;


// Vector2Parameter:5
	vec2 n_out5p0 = scale;


// UVFunc:4
	vec2 n_in4p2 = vec2(0.00000, 0.00000);
	vec2 n_out4p0 = (n_out7p0 - n_in4p2) * n_out5p0 + n_in4p2;


	vec4 n_out8p0;
// Texture2D:8
	n_out8p0 = texture(BaseTexture, n_out4p0);
	float n_out8p1 = n_out8p0.r;


// Vector2Parameter:43
	vec2 n_out43p0 = wind_speed;


// Input:35
	vec4 n_out35p0 = COLOR;
	float n_out35p4 = n_out35p0.a;


// ParameterRef:51
	float n_out51p0 = scroll_offset;


// FloatOp:50
	float n_out50p0 = n_out35p4 + n_out51p0;


// VectorOp:44
	vec2 n_out44p0 = n_out43p0 * vec2(n_out50p0);


// UVFunc:27
	vec2 n_in27p1 = vec2(1.00000, 1.00000);
	vec2 n_out27p0 = n_out44p0 * n_in27p1 + UV;


// Vector2Parameter:26
	vec2 n_out26p0 = wind_scale;


// UVFunc:25
	vec2 n_in25p2 = vec2(0.00000, 0.00000);
	vec2 n_out25p0 = (n_out27p0 - n_in25p2) * n_out26p0 + n_in25p2;


	vec4 n_out18p0;
// Texture2D:18
	n_out18p0 = texture(Wind_1_texture, n_out25p0);
	float n_out18p1 = n_out18p0.r;


// Reroute:39
	float n_out39p0 = n_out18p1;


// Vector2Parameter:45
	vec2 n_out45p0 = wind_2_speed;


// Input:36
	vec4 n_out36p0 = COLOR;
	float n_out36p4 = n_out36p0.a;


// ParameterRef:52
	float n_out52p0 = scroll_offset;


// FloatOp:53
	float n_out53p0 = n_out36p4 + n_out52p0;


// VectorOp:46
	vec2 n_out46p0 = n_out45p0 * vec2(n_out53p0);


// UVFunc:30
	vec2 n_in30p1 = vec2(1.00000, 1.00000);
	vec2 n_out30p0 = n_out46p0 * n_in30p1 + UV;


// Vector2Parameter:31
	vec2 n_out31p0 = wind_2_scale;


// UVFunc:29
	vec2 n_in29p2 = vec2(0.00000, 0.00000);
	vec2 n_out29p0 = (n_out30p0 - n_in29p2) * n_out31p0 + n_in29p2;


	vec4 n_out20p0;
// Texture2D:20
	n_out20p0 = texture(Wind_2_texture_subs, n_out29p0);
	float n_out20p1 = n_out20p0.r;


// Reroute:40
	float n_out40p0 = n_out20p1;


// FloatOp:22
	float n_out22p0 = n_out39p0 - n_out40p0;


// FloatOp:19
	float n_out19p0 = n_out8p1 * n_out22p0;


	vec4 n_out11p0;
// Texture2D:11
	n_out11p0 = texture(Multiply_Mask, UV);
	float n_out11p1 = n_out11p0.r;


// FloatOp:12
	float n_out12p0 = n_out19p0 * n_out11p1;


	vec4 n_out13p0;
// Texture2D:13
	n_out13p0 = texture(Color1DGradient, vec2(n_out12p0));
	float n_out13p4 = n_out13p0.a;


// Output:0
	ALBEDO = vec3(n_out13p0.xyz);
	ALPHA = n_out13p4;



ALBEDO*=psychic_tint.rgb;
ALPHA*=psychic_envelope*psychic_opacity*0.8;

ALPHA *= factory_occurrence_alpha;
}


