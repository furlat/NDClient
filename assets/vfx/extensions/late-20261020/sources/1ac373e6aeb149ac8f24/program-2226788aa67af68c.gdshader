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

render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D source_tex:source_color;
uniform vec4 source_tint:source_color=vec4(1.0);
uniform float payload_seconds=0.0;
uniform float payload_alpha=0.0;
varying float smoke_frame;
void vertex(){
 float angle=INSTANCE_CUSTOM.x;
 vec3 right=INV_VIEW_MATRIX[0].xyz*cos(angle)+INV_VIEW_MATRIX[1].xyz*sin(angle);
 vec3 up=-INV_VIEW_MATRIX[0].xyz*sin(angle)+INV_VIEW_MATRIX[1].xyz*cos(angle);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(INV_VIEW_MATRIX[2].xyz*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
 smoke_frame=clamp(floor(INSTANCE_CUSTOM.z*64.0),0.0,63.0);

vec4 payload_world4=(INV_VIEW_MATRIX*MODELVIEW_MATRIX)*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}
void fragment(){
 vec2 atlas_uv=(UV+vec2(mod(smoke_frame,8.0),floor(smoke_frame/8.0)))/8.0;
 vec4 colour=texture(source_tex,atlas_uv)*source_tint*COLOR;
 ALBEDO=colour.rgb*.7;
 ALPHA=colour.a*payload_alpha;

ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);

EMISSION+=ALBEDO*.24;

ALPHA*=.25;
}

