shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

uniform float psychic_clock=0.0;
uniform float psychic_envelope=0.0;
uniform float psychic_opacity=1.0;
uniform vec4 psychic_tint:source_color=vec4(1.0);

render_mode unshaded;

group_uniforms Color;
uniform vec3 primary_color : source_color = vec3(1.0,0.8,0.2);
uniform vec3 secondary_color : source_color = vec3(1.0,0.4,0.1);
uniform vec3 tertiary_color : source_color = vec3(0.6,0.1,0.05);
uniform float emission = 2.0;
uniform float color_curve = 1.0;
uniform float hue_variation = 0.1;
uniform bool use_secondary = false;

group_uniforms Shape;
uniform sampler2D noise_texture;
uniform vec2 noise_scale = vec2(0.5);
uniform vec2 noise_scroll = vec2(0.0, 0.1);
uniform float shape_curve = 2.0;
uniform float noise_twist : hint_range(-1.0, 1.0, 0.05) = 0.0;
uniform float waviness : hint_range(0.0, 1.0, 0.01) = 0.2;

group_uniforms Transparency;
uniform float edge_hardness : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float edge_position : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool proximity_fade = false;
uniform float proximity_fade_distance : hint_range(0.0, 4096.0, 0.01);
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

vec3 shift_hue(vec3 color, float shift) {
	vec3 gray = vec3(0.57735);
	vec3 projection = gray * dot(gray, color.rgb);
	vec3 U = color.rgb - projection;
	vec3 V = cross(gray, U);
	vec3 shifted = U * cos(shift * 2.0 * PI) + V * sin(shift * 2.0 * PI) + projection;
	return shifted;
}

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
	float r = length(UV * 2.0 - 1.0);
	
	vec2 noise_uv = (vec2(UV.x + UV.y * noise_twist, UV.y) + COLOR.r) * noise_scale + (noise_scroll * psychic_clock);
	
	float wave = sin(UV.y * 20.0 + psychic_clock * 6.0);
	noise_uv.x += wave * 0.1 * waviness;
	
	float noise = texture(noise_texture, noise_uv).r;
	
	float value = pow(max(noise - r, 0.0), shape_curve) * COLOR.a;
	
	float color_value = pow(value, color_curve);
	color_value = mix(color_value, floor(color_value * 6.0) / 5.0, edge_hardness);
	vec3 main_color = use_secondary ? secondary_color : primary_color;
	vec3 color = mix(tertiary_color, main_color, color_value);
	color = shift_hue(color, (COLOR.r - 0.5) * hue_variation) * (0.5 + COLOR.r * 0.5);
	
	ALBEDO = color * emission;
	ALPHA = value;
	
	// Proximity Fade: Enabled
	if(proximity_fade){
		float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec4 ndc = OUTPUT_IS_SRGB ? vec4(vec3(SCREEN_UV, proximity_depth_tex) * 2.0 - 1.0, 1.0) : vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
		vec4 proximity_view_pos = INV_PROJECTION_MATRIX * ndc;
		proximity_view_pos.xyz /= proximity_view_pos.w;
		ALPHA *= clamp(1.0 - smoothstep(proximity_view_pos.z + proximity_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	}
	
	ALPHA = clamp((ALPHA - edge_position) / (1.0 - edge_hardness), 0.0, 1.0);

ALBEDO*=psychic_tint.rgb;
ALPHA=(0.30+0.70*clamp(ALPHA,0.0,1.0))*pow(max(0.0,sin(UV.x*3.14159265)),0.65)*pow(max(0.0,sin(UV.y*3.14159265)),0.4);
ALPHA*=psychic_envelope*psychic_opacity*0.5;

ALPHA *= factory_occurrence_alpha;
}

