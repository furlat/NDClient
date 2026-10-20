shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform float clock=0.0;
uniform float ghost=0.0;
uniform float lightness=0.0;
uniform vec4 feast_role_tint:source_color=vec4(1.0);
uniform float feast_value_gain=1.0;
uniform mat4 feast_world_to_source;
uniform float feast_birth_seconds=0.0;
uniform vec2 feast_half_extent_cells=vec2(.50,.43);
varying vec3 local;
varying vec3 feast_point;
void vertex(){
 local=VERTEX;
 feast_point=(feast_world_to_source*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float lit=clamp(dot(world_normal,normalize(vec3(-.4,.8,.6)))*.43+.48,0.,1.);
 float flow=pow(.5+.5*sin(local.y*17.+local.x*7.-clock*6.283185),14.);
 vec3 c=mix(vec3(.045,.085,.085),vec3(.37,.59,.57),lit);
 c=mix(c,vec3(.78,.95,.87),clamp(rim*.68+flow*.18+lightness*.4,0.,.85));
 c*=feast_role_tint.rgb*feast_value_gain;
 ALBEDO=c;EMISSION=c*(.10+ghost*.16+lightness*.2);
 
 float radius=length(feast_point.xz/feast_half_extent_cells);
 float gathered=smoothstep(.02,.60,feast_birth_seconds)*1.65;
 float irregular=.045*sin(feast_point.x*31.+feast_point.z*17.)+.025*sin(feast_point.z*37.-feast_point.x*11.);
 float materialized=1.0-smoothstep(gathered-.035,gathered+.035,radius+irregular);
 ALPHA=materialized;

ALPHA *= factory_occurrence_alpha;
}




