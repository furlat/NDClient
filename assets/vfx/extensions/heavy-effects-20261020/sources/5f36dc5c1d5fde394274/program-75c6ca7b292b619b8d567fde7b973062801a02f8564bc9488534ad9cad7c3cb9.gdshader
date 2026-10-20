shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_payload_seconds=0.0;

varying vec3 payload_actual_world;
uniform vec3 payload_footprint_origin=vec3(0.0);
uniform vec2 payload_cells[128];
uniform vec4 payload_open_edges[128];
uniform int payload_cell_count=0;
float payload_membership(vec2 point){
 float coverage=0.0;
 for(int i=0;i<128;i++){
  if(i>=payload_cell_count)break;
  vec2 relative=point-payload_cells[i];vec2 distance=abs(relative);vec4 edges=payload_open_edges[i];
  float edge_x=relative.x<0.0?edges.x:edges.y;float edge_y=relative.y<0.0?edges.z:edges.w;
  float inside=1.0-step(0.50001,max(distance.x,distance.y));
  float soft_x=mix(1.0,smoothstep(0.015,0.13,0.5-distance.x),edge_x);
  float soft_y=mix(1.0,smoothstep(0.015,0.13,0.5-distance.y),edge_y);
  vec2 corner=max(distance-vec2(0.25),vec2(0.0));float rounding=1.0-smoothstep(0.20,0.25,length(corner));
  coverage=max(coverage,inside*soft_x*soft_y*mix(1.0,rounding,edge_x*edge_y));
 }
 return coverage;
}

render_mode blend_mix,unshaded,cull_disabled,depth_draw_never;
uniform sampler2D native_texture:source_color;
uniform bool has_texture=false;
uniform vec4 native_tint:source_color=vec4(1.0);
uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
void fragment(){
 vec4 source=COLOR*native_tint;
 if(has_texture){source*=texture(native_texture,UV);}
 ALBEDO=source.rgb;
 ALPHA=source.a*payload_alpha;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);
}

void vertex(){
vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}

