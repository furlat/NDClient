shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float pressure_edge_start=0.28;
uniform float pressure_edge_end=0.92;
uniform float pressure_alpha_cap=0.32;
uniform float pressure_band_gain=0.28;
uniform float pressure_streak_gain=0.055;

render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float opacity=0.0;
uniform bool front=true;
uniform float ground_y=0.0;
uniform float clock=0.0;
varying vec3 local_pos;
void vertex(){local_pos=VERTEX; VERTEX*=0.97+0.03*sin(VERTEX.x*17.0+VERTEX.y*13.0+VERTEX.z*11.0);}
void fragment(){
	vec3 world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	if(world.y<ground_y)discard;
	float depth=dot(world,vec3(0.70710678,0.0,0.70710678));
	
	
	float edge=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.2);
	vec3 p=normalize(world);
	float mask=sin(p.x*8.5+p.z*2.1+0.6)+0.55*sin(p.y*6.1-p.z*4.3+1.8);
	float arcs=smoothstep(-0.55,0.25,mask);
	float band=smoothstep(pressure_edge_start,pressure_edge_end,edge)*(0.15+0.85*arcs);
	float energy_path=abs(sin(p.x*10.0+p.y*7.0+p.z*8.0+sin(p.z*13.0)*1.3));
	float streak=1.0-smoothstep(0.045,0.16,energy_path);
	float irregular=0.6+0.4*sin(p.y*21.0+p.x*15.0+p.z*12.0+clock*19.0);
	float tear_progress=smoothstep(0.19,0.43,clock);
	float tear_field=sin(p.x*4.8+p.z*2.3+0.7)+0.62*sin(p.y*5.9-p.z*3.7+1.8);
	float tear=(1.0-tear_progress)*mix(1.0,0.75+0.25*smoothstep(-1.62,1.62,tear_field),tear_progress);
	float veil=0.15*arcs;
	float energy=max(band,streak*irregular*0.16);
	ALBEDO=vec3(0.48,0.30,0.76)+vec3(0.34,0.38,0.24)*energy;
	ALPHA=min(pressure_alpha_cap,band*pressure_band_gain+streak*irregular*pressure_streak_gain)*opacity*tear;
}



