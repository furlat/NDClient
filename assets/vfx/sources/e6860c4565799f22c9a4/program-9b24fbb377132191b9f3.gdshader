shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;
render_mode unshaded,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 camera_sign;uniform bool front=false;void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<0.0)discard;float rim=pow(1.0-abs(dot(NORMAL,VIEW)),1.8);ALBEDO=vec3(.45,.69,.80);ALPHA=(.02+.07*rim)*opacity;
ALPHA *= factory_occurrence_alpha;
}


