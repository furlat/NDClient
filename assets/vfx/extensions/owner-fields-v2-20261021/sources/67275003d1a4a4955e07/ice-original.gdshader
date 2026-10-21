shader_type spatial;
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

render_mode blend_mix,cull_disabled,unshaded;
uniform sampler2D native_ice:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D native_orm:repeat_enable,filter_linear_mipmap;
uniform float payload_alpha=0.0;
varying vec2 native_ice_world;
void vertex(){vec4 ice_world4=MODEL_MATRIX*vec4(VERTEX,1.0);native_ice_world=ice_world4.xz;
vec4 payload_world4=MODEL_MATRIX*vec4(VERTEX,1.0);payload_actual_world=payload_world4.xyz;
}
void fragment(){vec4 ice=texture(native_ice,native_ice_world*0.31);vec3 orm=texture(native_orm,native_ice_world*0.31).rgb;float frost=smoothstep(0.38,0.86,dot(ice.rgb,vec3(0.2126,0.7152,0.0722)));ALBEDO=mix(ice.rgb*vec3(0.40,0.58,0.70),ice.rgb*0.9,frost);ROUGHNESS=orm.g;METALLIC=orm.b;ALPHA=(0.35+0.30*frost+0.35*ice.a)*payload_alpha*1.1;
ALPHA*=payload_membership(payload_actual_world.xz-payload_footprint_origin.xz)*smoothstep(-0.02,0.035,payload_actual_world.y-payload_footprint_origin.y);
}
