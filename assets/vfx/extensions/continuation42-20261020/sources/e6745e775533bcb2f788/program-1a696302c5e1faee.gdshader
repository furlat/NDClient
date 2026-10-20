shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;render_mode unshaded,blend_add,cull_disabled,depth_draw_never;uniform sampler2D tex:source_color;uniform vec4 tint:source_color=vec4(1.0);void vertex(){float c=cos(INSTANCE_CUSTOM.x);float s=sin(INSTANCE_CUSTOM.x);mat4 bb=mat4((INV_VIEW_MATRIX[0]*c+INV_VIEW_MATRIX[1]*s)*length(MODEL_MATRIX[0].xyz),(-INV_VIEW_MATRIX[0]*s+INV_VIEW_MATRIX[1]*c)*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}void fragment(){vec4 c=texture(tex,UV)*tint*COLOR;ALBEDO=c.rgb;ALPHA=c.a;
ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}


