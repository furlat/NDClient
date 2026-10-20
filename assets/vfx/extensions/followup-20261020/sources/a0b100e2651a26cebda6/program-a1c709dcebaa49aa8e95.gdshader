shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float pressure_compression_gain=0.22;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float opacity=0.0;
uniform bool front=true;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX;}
void fragment(){
	vec3 world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	if(world.y<0.0)discard;
	float depth=dot(world,vec3(0.70710678,0.0,0.70710678));
	
	
	float irregular=0.45+0.4*sin(local_pos.x*4.7+0.2)*sin(local_pos.y*6.1-0.8)+0.35*sin(local_pos.z*7.1+1.1);
	float soft=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),0.75);
	ALBEDO=vec3(0.46,0.26,0.75)+vec3(0.4,0.44,0.25)*max(0.0,irregular);
	ALPHA=soft*smoothstep(-0.3,0.65,irregular)*opacity*pressure_compression_gain;
}



