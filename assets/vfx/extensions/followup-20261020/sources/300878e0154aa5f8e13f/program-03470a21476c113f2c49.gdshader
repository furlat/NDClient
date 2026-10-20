shader_type spatial;
uniform float factory_occurrence_alpha=1.0;
 render_mode unshaded,cull_disabled; uniform sampler2D glow_mask:filter_linear; uniform vec4 glow_color:source_color; uniform float glow_alpha=0.0; void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]); } void fragment(){ ALBEDO=glow_color.rgb; ALPHA=texture(glow_mask,UV).r*glow_alpha; 
ALPHA *= factory_occurrence_alpha;
}



