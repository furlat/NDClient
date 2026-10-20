shader_type spatial;
uniform sampler2D factory_liquid_clock_texture : filter_nearest, repeat_disable;
uniform sampler2D factory_liquid_field_texture : filter_nearest, repeat_disable;
vec4 factory_liquid_field(int index) { return texelFetch(factory_liquid_field_texture,ivec2(index,0),0); }
float factory_liquid_clock() { return texelFetch(factory_liquid_clock_texture,ivec2(0,0),0).r; }
float factory_liquid_surface_seconds() { return texelFetch(factory_liquid_clock_texture,ivec2(0,0),0).g; }

render_mode unshaded,cull_disabled,blend_mix;
uniform sampler2D footprint:filter_nearest,repeat_disable;
uniform sampler2D marble:filter_linear,repeat_enable;


uniform int material_kind=0;
uniform vec4 dark:source_color=vec4(.17,.15,.13,1.0);
uniform vec4 mid:source_color=vec4(.32,.30,.25,1.0);
uniform vec4 light:source_color=vec4(.62,.59,.47,1.0);
uniform float body_alpha=.6;
uniform sampler2D frost : repeat_enable, filter_linear;
uniform float freeze_fraction = 0.;
uniform float thaw_fraction = 0.;
uniform float transition_seconds = 0.;
uniform vec2 contact_point = vec2(0.);
uniform bool frozen_blood = false;
uniform float retirement = 1.;
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

void fragment(){
 // Shared world-space domain, never restart UV or animation at cell borders.
 vec2 world=UV*4.0-.5;
 float phase=(factory_liquid_clock()-1.0)*3.14159265359;
 float activity=mix(1.0,.10,smoothstep(.8,2.0,factory_liquid_clock()));
 vec2 drift=vec2(sin(phase),cos(phase))*.025*activity;
 vec2 point=world-1.5;
 float density=0.0;
 for(int i=0;i<160;i++){
  float on_floor=1.0-smoothstep(.03,.09,factory_liquid_field(i).y);
  float d=length(point-factory_liquid_field(i).xz)/.26;
  density+=max(0.0,1.0-d*d)*max(0.0,1.0-d*d)*on_floor;
 }
 float coverage_alpha=smoothstep(.48,.66,density);
 float edge_glint=exp(-pow((density-.72)/.25,2.0));
 float end=1.0;
 vec2 p=(world-1.5)/1.08;
 float n=texture(marble,world*.675+drift).r;
 // Low-contrast moving material texture; no repeated bright stripe highlights.
 float n2=texture(marble,world*.49-drift*.65+vec2(.27,.16)).r;
 float glint=.07*smoothstep(.65,.98,n*n2);
 float shade=.16+n*.35;
 if(material_kind==0){shade=n*.10;glint=.11*smoothstep(.55,.92,n2);}
 else if(material_kind==2){shade=n*.18;glint=.05*smoothstep(.65,.94,n2);}
 else if(material_kind==3){shade=n*.28;glint=.045*smoothstep(.63,.95,n2);}
 else if(material_kind==4){shade=.12+n*n2*.48;glint=.08*smoothstep(.60,.95,n2);}
 else if(material_kind==5){shade=n*.22;glint=.05*smoothstep(.68,.96,n2);}
 vec3 liquid = mix(mix(dark.rgb,mid.rgb,shade),light.rgb,glint);
 float distance_from_contact = length(point-contact_point);
 float ice_noise = texture(frost,point*.7).r;
 float freeze_front = smoothstep(0.,.4,transition_seconds-distance_from_contact*.38-ice_noise*.12);
 vec4 state=factory_surface_states(point,ice_noise); float frozen=state.x;
 float crystal = texture(frost,point*.39+vec2(.17,.31)).r;
 vec3 icy = mix(vec3(.18,.37,.53),vec3(.55,.76,.86),crystal*.8);
 icy = frozen_blood ? mix(liquid,icy,.43) : icy;
 ALBEDO = mix(liquid,icy,frozen);
 EMISSION = icy * frozen * .035;
 ALPHA=coverage_alpha*end*min(1.0,body_alpha+glint*.48)*retirement*(1.-state.w);
}


