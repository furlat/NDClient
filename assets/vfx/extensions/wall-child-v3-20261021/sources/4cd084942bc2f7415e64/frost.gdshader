shader_type spatial;
instance uniform float solid_flake_opacity=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;uniform float opacity=0.0;uniform vec2 actor_ground=vec2(0.0);uniform vec2 camera_ground=vec2(.70710678);uniform bool foreground=false;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
uniform sampler2D child_cells:filter_nearest,repeat_disable;
uniform vec2 child_mask_origin=vec2(0.0);
uniform vec2 child_mask_size=vec2(1.0);
float child_cell_coverage(vec2 point){
	vec2 cell=floor(point/2.121320344+vec2(.5))-child_mask_origin;
	if(any(lessThan(cell,vec2(0.0)))||any(greaterThanEqual(cell,child_mask_size)))return 0.0;
	return texture(child_cells,(cell+vec2(.5))/child_mask_size).r;
}
void fragment(){vec2 q=UV*2.0-1.0;float soft=(1.0-smoothstep(.15,1.0,length(q)));ALBEDO=vec3(.67,.82,.89);float spoke=exp(-pow(sin(atan(q.y,q.x)*3.0)*length(q)*5.0,2.0)); ALPHA=opacity*soft*(.3+.7*spoke);vec3 wp=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;if(wp.y<0.0 || child_cell_coverage(wp.xz)<.5)discard;
ALPHA *= factory_occurrence_alpha;

ALPHA*=solid_flake_opacity;
}


