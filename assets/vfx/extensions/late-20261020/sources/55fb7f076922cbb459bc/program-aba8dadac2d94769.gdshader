shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_source_clock=0.0;
uniform float vfx_package_offset_surface_seconds=0.0;

uniform sampler2D silk_grain:repeat_enable,filter_linear;

uniform float owner_envelope=1.;
render_mode cull_disabled,depth_draw_never;
uniform sampler2D silk_texture:source_color,filter_linear;
uniform float source_clock=0.;
uniform vec2 forward_axis=vec2(1.,0.);
varying vec2 surface_local_point;
void vertex(){
 vec2 q=VERTEX.xz;float radius=length(q);float edge=max(abs(q.x),abs(q.y));
 // Spread the donor's circular network toward the square gameplay footprint,
 // with a soft irregular perimeter rather than a cutout mask.
 float square_factor=radius/max(edge,.0001);
 q*=mix(1.,square_factor,.82);
 float angle=atan(q.y,q.x);
 // Uneven perimeter stays outside the required cell coverage.
 float irregular=.065*sin(angle*3.+.7)+.04*sin(angle*2.-1.3);
 float bend=.10*sin(radius*.7+angle*2.)*min(radius/3.,1.);
 q=mat2(vec2(cos(bend),sin(bend)),vec2(-sin(bend),cos(bend)))*q;
 q*=1.+irregular;
 q+=vec2(sin(q.y*1.05+.7),sin(q.x*.87-1.1))*.18*min(radius/3.,1.);
 vec2 side=vec2(-forward_axis.y,forward_axis.x);
 float cross=dot(q,side);float along=dot(q,forward_axis);
 float order=clamp((along+5.3)/10.6,0.,1.);
 float trailing=(1.-order);
 vec2 contact=vec2(1.,1.);
 vec2 folded=contact+side*(cross*.09+sin(along*3.2)*.035*trailing)-forward_axis*(trailing*1.55);
 float folded_height=.06+(.08+.10*cos(cross*2.5))*trailing;
 vec2 from_hit=q-contact;
 float sector=atan(from_hit.y,from_hit.x);
 float stagger=.5+.30*sin(sector*3.+.8)+.20*sin(sector*5.-.6);
 float delay=.02+.24*stagger+length(from_hit)*.008;
 float duration=.62+.40*(.5+.5*sin(sector*2.-1.2));
 float phase=smoothstep(delay,delay+duration,(vfx_package_seconds()+vfx_package_offset_source_clock));
 // Separate sectors pull, hesitate and settle while remaining connected.
 phase=clamp(phase+.075*sin(phase*6.2831853)*sin(sector*3.+1.1),0.,1.);
 VERTEX.xz=mix(folded,q,phase);
 float lift=sin(phase*3.14159265)*(.32+.36*order)*(.8+.2*cos(cross));
 float rest_height=.035+.016*(1.+sin(q.x*2.+q.y*1.7));
 VERTEX.y=mix(folded_height,rest_height,phase)+lift;
 // Small living fold in flight, reaching exactly zero at the shared contact frame.
 VERTEX.y+=(vfx_package_seconds()+vfx_package_offset_source_clock)<0.?sin((vfx_package_seconds()+vfx_package_offset_source_clock)*15.+along*2.)*.025*trailing*min(1.,-(vfx_package_seconds()+vfx_package_offset_source_clock)*8.):0.;
surface_local_point=VERTEX.xz/2.121320344;
}
// Presentation of committed operations, clipped to their admitted ground cells.
// The density/coverage geometry belongs to the liquid, not to this state front.
uniform vec4 surface_contacts[32]; // local x, z, start seconds, front seconds
uniform vec4 surface_regions[32]; // xmin, zmin, xmax, zmax
uniform int surface_operations[32]; // freeze, thaw, charge, vaporize, clear, uncharge, ignite, douse
uniform int surface_event_count = 0;
uniform float surface_seconds = 0.;

vec4 factory_surface_states(vec2 point, float detail) {
	vec4 state = vec4(0.); // frozen, charged, burning, removed
	for (int i=0; i<32; i++) {
		if (i>=surface_event_count) break;
		vec4 contact=surface_contacts[i];
		vec4 region=surface_regions[i];
		if ((vfx_package_seconds()+vfx_package_offset_surface_seconds)<contact.z) continue;
		float admitted=step(region.x,point.x)*step(region.y,point.y)
			*step(point.x,region.z)*step(point.y,region.w);
		float travel=(vfx_package_seconds()+vfx_package_offset_surface_seconds)-contact.z;
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

void fragment(){
 vec4 silk=texture(silk_texture,UV);
 ALBEDO=vec3(.65,.68,.61);
 ALPHA=smoothstep(.04,.55,silk.a)*mix(.42,1.,smoothstep(.035,.22,length(UV-vec2(.5))));

vec4 state=factory_surface_states(surface_local_point,0.); ALBEDO=mix(ALBEDO,vec3(.065,.035,.02),state.z); EMISSION=vec3(.7,.12,.015)*state.z*(1.-state.z); ALPHA*= (1.-smoothstep(.5,1.,state.z))*(1.-state.w)*owner_envelope;

float silk_variation=texture(silk_grain,surface_local_point*.55).r;
ALBEDO*=mix(.68,1.0,silk_variation);
ROUGHNESS=.62;
SPECULAR=.35;
}

