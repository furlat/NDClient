shader_type spatial;
instance uniform float solid_flake_opacity=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;
render_mode unshaded,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 camera_sign;uniform bool front=false;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}void fragment(){vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;vec2 q=UV*2.0-1.0;ALBEDO=vec3(.67,.82,.89);ALPHA=opacity*(1.0-smoothstep(.15,1.0,length(q)));
ALPHA *= factory_occurrence_alpha;

ALPHA*=solid_flake_opacity;
}


