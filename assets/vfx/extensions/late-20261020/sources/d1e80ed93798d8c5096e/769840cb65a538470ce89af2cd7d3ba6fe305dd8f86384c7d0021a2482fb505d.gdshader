shader_type spatial;
uniform sampler2D factory_liquid_clock_texture : filter_nearest, repeat_disable;
uniform sampler2D factory_liquid_field_texture : filter_nearest, repeat_disable;
vec4 factory_liquid_field(int index) { return texelFetch(factory_liquid_field_texture,ivec2(index,0),0); }
float factory_liquid_surface_seconds() { return texelFetch(factory_liquid_clock_texture,ivec2(0,0),0).g; }
float factory_liquid_electric_clock() { return texelFetch(factory_liquid_clock_texture,ivec2(0,0),0).b; }
float factory_liquid_gpu_opacity() { return texelFetch(factory_liquid_clock_texture,ivec2(1,0),0).b; }
uniform sampler2D factory_liquid_link_texture : filter_nearest, repeat_disable;
instance uniform int factory_liquid_link_index=0;
vec3 factory_liquid_gpu_link_from() { return texelFetch(factory_liquid_link_texture,ivec2(0,factory_liquid_link_index),0).xyz; }
vec3 factory_liquid_gpu_link_to() { return texelFetch(factory_liquid_link_texture,ivec2(1,factory_liquid_link_index),0).xyz; }
float factory_liquid_gpu_edge_delay() { return texelFetch(factory_liquid_link_texture,ivec2(0,factory_liquid_link_index),0).w; }

render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.42, 0.52, 1.0, 1.0);
uniform float emission : hint_range(0.0, 12.0, 0.05) = 3.2;
uniform float alpha_mult : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D noise_tex : repeat_enable;
uniform float noise_scale = 3.5;
uniform float noise_scroll = 1.6;

varying vec2 v_uv;



varying vec2 field_point;
// Original seeded local detail, live endpoint deformation and finite growth.
// Original Boringdev core/glow fragment and view-facing width code remain.
uniform sampler2D gpu_shape_atlas : filter_nearest, repeat_disable;
uniform int gpu_primary_segments = 131;
uniform int gpu_primary_lanes = 1;
uniform int gpu_fork_count = 36;
uniform int gpu_fork_samples = 13;
uniform int gpu_variations = 32;



uniform float gpu_speed = 26.0;
uniform float gpu_width = .32;

uniform bool gpu_persistent = false;
uniform bool gpu_glow = false;
uniform bool gpu_secondary_mode = false;
uniform vec4 gpu_secondary_windows[4];
uniform float gpu_link_width_gain = 1.0;
uniform float gpu_fork_width_gain = 1.0;
uniform float gpu_plane_y = 1.0e20;
varying float gpu_ribbon_alpha;

vec3 gpu_axis() {
	vec3 delta = factory_liquid_gpu_link_to()-factory_liquid_gpu_link_from();
	return length(delta)>.000001?normalize(delta):vec3(0.0,0.0,1.0);
}
vec3 gpu_side() {
	vec3 value=cross(gpu_axis(),vec3(0.0,1.0,0.0));
	return length(value)>.000001?normalize(value):vec3(1.0,0.0,0.0);
}
vec3 gpu_flatten(vec3 value) {
	if(gpu_plane_y<1.0e19)value.y=gpu_plane_y;
	return value;
}
vec4 gpu_detail(int index) {
	float cursor=max(0.0,factory_liquid_electric_clock())*11.0;
	int frame=int(floor(cursor))%gpu_variations;
	float weight=smoothstep(0.0,1.0,fract(cursor));
	return mix(texelFetch(gpu_shape_atlas,ivec2(index,frame+factory_liquid_link_index*gpu_variations),0),texelFetch(gpu_shape_atlas,ivec2(index,(frame+1)%gpu_variations+factory_liquid_link_index*gpu_variations),0),weight);
}
vec3 gpu_spine(int lane,int index,int segments) {
	if(index<=0)return gpu_flatten(factory_liquid_gpu_link_from());
	if(index>=segments)return gpu_flatten(factory_liquid_gpu_link_to());
	float ratio=float(index)/float(segments);
	vec4 detail=gpu_detail(lane*(gpu_primary_segments+1)+index);
	float envelope=gpu_primary_lanes>1?smoothstep(0.0,.055,ratio)*(1.0-.4*smoothstep(.9,1.0,ratio)):sin(ratio*3.14159265359);
	return gpu_flatten(mix(factory_liquid_gpu_link_from(),factory_liquid_gpu_link_to(),ratio)+gpu_side()*detail.x*envelope+vec3(0.0,1.0,0.0)*detail.y*envelope);
}
vec3 gpu_spine_at(int lane,float index,int segments) {
	int lower=int(floor(index));
	return mix(gpu_spine(lane,lower,segments),gpu_spine(lane,min(lower+1,segments),segments),fract(index));
}
vec4 gpu_fork_detail(int fork,float progress) {
	float cursor=progress*float(gpu_fork_samples-1);
	int lower=int(floor(cursor));
	int begin=gpu_primary_lanes*(gpu_primary_segments+1)+fork*gpu_fork_samples;
	return mix(gpu_detail(begin+lower),gpu_detail(begin+min(lower+1,gpu_fork_samples-1)),fract(cursor));
}
int gpu_anchor(int fork,int segments) {
	return clamp(int(floor(gpu_fork_detail(fork,0.0).w*float(segments)+.5)),1,max(1,segments-2));
}
vec3 gpu_route_point(int path,float progress,int segments,int first,int last) {
	if(path<gpu_primary_lanes) {
		float index=mix(float(first),float(last),progress);
		if(gpu_secondary_mode && path>0 && (progress<=0.0 || progress>=1.0))return gpu_spine_at(0,index,segments);
		return gpu_spine_at(path,index,segments);
	}
	int fork=path-gpu_primary_lanes;
	int anchor=gpu_anchor(fork,segments);
	vec3 start=gpu_spine(0,anchor,segments);
	vec3 relative=gpu_fork_detail(fork,progress).xyz;
	if(gpu_primary_lanes>1) {
		vec3 end=gpu_spine((fork+2)%5,min(segments,anchor+1),segments);
		relative-=gpu_fork_detail(fork,1.0).xyz*progress;
		return gpu_flatten(mix(start,end,progress)+gpu_side()*relative.x+vec3(0.0,1.0,0.0)*relative.y+gpu_axis()*relative.z);
	}
	return gpu_flatten(start+gpu_side()*relative.x+vec3(0.0,1.0,0.0)*relative.y+gpu_axis()*relative.z);
}
void gpu_electric_deform(inout vec3 point,inout vec3 tangent,inout vec4 ribbon_color,inout vec2 source_uv,out float ribbon_energy) {
	int index=int(point.x+.5);
	int path=int(point.y+.5);
	int layer=int(point.z+.5);
	float distance=length(factory_liquid_gpu_link_to()-factory_liquid_gpu_link_from());
	if(distance<.00001 || (path>=gpu_primary_lanes && path-gpu_primary_lanes>=max(2,int(ceil(distance*1.2))))) {
		point=vec3(0.0);tangent=vec3(0.0,1.0,0.0);ribbon_color=vec4(0.0);source_uv.y=0.0;ribbon_energy=0.0;
		return;
	}
	int segments=max(gpu_primary_lanes>1?18:2,int(ceil(distance/.23)));
	float travel=max(.045,distance/gpu_speed);
	float age=factory_liquid_electric_clock()-factory_liquid_gpu_edge_delay();
	float envelope=smoothstep(-.025,.015,age)*factory_liquid_gpu_opacity();
	if(!gpu_persistent)envelope*=1.0-smoothstep(travel+.30,travel+.60,age);
	float ratio=clamp(age/travel,0.0,1.0);
	int first=0;
	int last=segments;
	float width=path==0 && gpu_primary_lanes>1?1.18:.52;
	if(gpu_secondary_mode && path>0 && path<gpu_primary_lanes) {
		vec4 window=gpu_secondary_windows[path-1];
		first=clamp(int(floor(window.x*float(segments)+.5)),1,segments-2);
		last=clamp(int(floor(window.y*float(segments)+.5)),first+2,segments);
		width*=window.z;
		ratio=clamp((ratio-float(first)/float(segments))*8.0,0.0,1.0);
	}
	int count=last-first;
	if(path>=gpu_primary_lanes) {
		int fork=path-gpu_primary_lanes;
		count=gpu_fork_samples-1;
		width=.16*gpu_fork_width_gain;
		ratio=clamp((ratio-float(gpu_anchor(fork,segments))/float(segments))*8.0,0.0,1.0);
		if(fork>=max(2,int(ceil(distance*1.2))))envelope=0.0;
	} else if(gpu_primary_lanes==1)width*=gpu_link_width_gain;
	int shown=ratio<1.0?int(floor(ratio*float(count)))+1:count;
	float cursor=min(float(index),ratio*float(count));
	point=gpu_route_point(path,cursor/float(count),segments,first,last);
	vec3 before=gpu_route_point(path,min(float(max(index-1,0)),ratio*float(count))/float(count),segments,first,last);
	vec3 after=gpu_route_point(path,min(float(min(index+1,shown)),ratio*float(count))/float(count),segments,first,last);
	tangent=length(after-before)>.0001?normalize(after-before):vec3(0.0,1.0,0.0);
	float progress=min(float(index)/float(max(1,shown)),1.0);
	float thickness=gpu_glow?1.7:(layer==0?.5:(layer==1?.28:.13));
	ribbon_color=vec4(gpu_width*width/.52*thickness*(.55+.45*sin(progress*3.14159265359))*.5,0.0,0.0,1.0);
	if(index>shown || age<0.0 || distance<.00001)ribbon_color.r=0.0;
	source_uv.y=progress;
	ribbon_energy=envelope;
}

void vertex() {
float gpu_energy_at_vertex; gpu_electric_deform(VERTEX,NORMAL,COLOR,UV,gpu_energy_at_vertex); gpu_ribbon_alpha=gpu_energy_at_vertex;

	field_point=VERTEX.xz;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vt = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float tl = length(vt);
	vt = tl > 0.0001 ? vt / tl : vec3(0.0, 1.0, 0.0);
	vec3 viewdir = normalize(-vp.xyz);
	vec3 right = cross(vt, viewdir);
	float rl = length(right);
	right = rl > 0.0001 ? right / rl : vec3(1.0, 0.0, 0.0);
	float side = (UV.x - 0.5) * 2.0;
	vp.xyz += right * side * COLOR.r;
	v_uv = UV;
	POSITION = PROJECTION_MATRIX * vp;
}

// Presentation of committed operations, clipped to their admitted ground cells.
// The density/coverage geometry belongs to the liquid, not to this state front.
uniform vec4 surface_contacts[32]; // local x, z, start seconds, front seconds
uniform vec4 surface_regions[32]; // xmin, zmin, xmax, zmax
uniform int surface_operations[32]; // freeze, thaw, charge, vaporize, clear, uncharge, ignite, douse
uniform int surface_event_count = 0;


vec4 factory_surface_states(vec2 point, float detail) {
	vec4 state = vec4(0.); // frozen, charged, burning, removed
	for (int i=0; i<32; i++) {
		if (i>=surface_event_count) break;
		vec4 contact=surface_contacts[i];
		vec4 region=surface_regions[i];
		if (factory_liquid_surface_seconds()<contact.z) continue;
		float admitted=step(region.x,point.x)*step(region.y,point.y)
			*step(point.x,region.z)*step(point.y,region.w);
		float travel=factory_liquid_surface_seconds()-contact.z;
		float front=admitted*smoothstep(0.,max(.03,contact.w),
			travel-length(point-contact.xy)*.19-detail*.035);
		int operation=surface_operations[i];
		if (operation==1) { state.x=mix(state.x,1.,front); state.y*=1.-front; }
		else if (operation==2) state.x*=1.-front;
		else if (operation==3) state.y=mix(state.y,1.,front)*(1.-state.x)*(1.-state.w);
		else if (operation==4) { state.z=0.; state.w=max(state.w,front); state.y*=1.-front; }
		else if (operation==5) { state.w=max(state.w,front); state.y*=1.-front; state.z*=1.-front; }
		else if (operation==6) state.y*=1.-front;
		else if (operation==7) state.z=mix(state.z,1.,front)*(1.-state.w);
		else if (operation==8) { state.w=max(state.w,front); state.z*=1.-front; state.y*=1.-front; }
	}
	return state;
}

void fragment() {
	float density=0.;
	for(int i=0;i<160;i++){
		float on_floor=1.-smoothstep(.03,.09,factory_liquid_field(i).y);
		float d=length(field_point-factory_liquid_field(i).xz)/.26;
		density+=pow(max(0.,1.-d*d),2.)*on_floor;
	}
	if(density<.48)discard;
if(factory_surface_states(field_point,0.).y<.08)discard;
	float cu = abs(v_uv.x - 0.5) * 2.0;
	float edge = clamp(1.0 - cu, 0.0, 1.0);

	vec2 nuv = vec2(v_uv.x * 0.6, v_uv.y * noise_scale - factory_liquid_electric_clock() * noise_scroll);
	float n1 = texture(noise_tex, nuv).r;
	float n2 = texture(noise_tex, nuv * 2.3 + vec2(0.37, -factory_liquid_electric_clock() * noise_scroll * 1.9)).r;
	float flow = 0.55 + 0.9 * mix(n1, n2, 0.5);

	float halo = pow(edge, 1.1);
	float core = pow(edge, 2.4) * (0.7 + 0.55 * flow);
	float hot = pow(edge, 4.6) * (0.45 + 1.25 * flow);
	float ends = smoothstep(0.0, 0.05, v_uv.y) * smoothstep(1.0, 0.85, v_uv.y);

	vec3 col = glow_color.rgb * halo * 0.4;
	col += core_color.rgb * core * 0.6;
	col += vec3(0.60, 0.86, 1.0) * pow(edge, 14.0) * hot * 0.14;
	float a = max(halo * 0.42, core) * ends;

	ALBEDO = col;
	EMISSION = col * emission * (0.45 + core * 2.8);
	ALPHA = clamp(a, 0.0, 1.0) * alpha_mult;

ALPHA *= gpu_ribbon_alpha;
}


