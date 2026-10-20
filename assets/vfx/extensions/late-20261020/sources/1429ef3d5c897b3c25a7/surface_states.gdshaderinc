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
		if (surface_seconds<contact.z) continue;
		float admitted=step(region.x,point.x)*step(region.y,point.y)
			*step(point.x,region.z)*step(point.y,region.w);
		float travel=surface_seconds-contact.z;
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
