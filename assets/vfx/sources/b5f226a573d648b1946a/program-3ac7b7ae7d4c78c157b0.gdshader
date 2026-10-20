shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,blend_mix,depth_draw_never,cull_back;
uniform sampler2D cold_noise:repeat_enable,filter_linear;
uniform float wall_clock=0.0;
uniform float opacity=0.0;
uniform vec2 actor_ground=vec2(0.0);
uniform vec2 camera_ground=vec2(.70710678);
uniform bool foreground=false;
uniform vec3 centre;
uniform vec3 half_extent;
void fragment(){
	vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;
	vec3 ray=-normalize((INV_VIEW_MATRIX*vec4(VIEW,0.0)).xyz);
	vec3 safe_ray=sign(ray)*max(abs(ray),vec3(.0001));
	vec3 p=wp-centre;
	vec3 limits=(sign(safe_ray)*half_extent-p)/safe_ray;
	float travel=max(0.0,min(limits.x,min(limits.y,limits.z)));
	float step_size=travel/16.0;
	// The vapour is stationary: no advected fine texture or quantized colour chatter.
	float density=0.0;
	for(int i=0;i<16;i++){
		vec3 sample_point=p+ray*(float(i)+.5)*step_size;
		vec3 world_point=sample_point+centre;
		// Split the completed colour once, after rendering; never reblend the surface layers.
		vec3 edge=(half_extent-abs(sample_point))/half_extent;
		float boundary=smoothstep(0.0,.22,edge.x)*smoothstep(0.0,.20,edge.y)*smoothstep(0.0,.32,edge.z);
		float cloud=.62+.10*cos(sample_point.x*.85+sample_point.y*.40)+.08*cos(sample_point.z*.72-sample_point.y*.55);
		density+=boundary*cloud*step_size;
	}
	ALBEDO=vec3(.49,.76,.87);
	ALPHA=opacity*(1.0-exp(-density*.70));

ALPHA *= factory_occurrence_alpha;
}



