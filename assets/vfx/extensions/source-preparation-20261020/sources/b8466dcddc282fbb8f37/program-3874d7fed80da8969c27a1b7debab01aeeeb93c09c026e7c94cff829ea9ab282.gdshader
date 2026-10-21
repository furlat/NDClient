shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;
uniform float vfx_package_offset_support_age=0.0;

uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_tex:source_color;uniform vec4 source_tint:source_color=vec4(1.0);void vertex(){vec3 up=vec3(0.0,1.0,0.0);vec3 right=normalize(INV_VIEW_MATRIX[0].xyz);vec3 forward=normalize(cross(right,up));mat4 bb=mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(forward*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

vec4 c=texture(source_tex,UV)*source_tint*COLOR;ALBEDO=c.rgb*0.7;ALPHA=c.a;
ALPHA *= support_envelope;

ALPHA *= factory_occurrence_alpha;
}



