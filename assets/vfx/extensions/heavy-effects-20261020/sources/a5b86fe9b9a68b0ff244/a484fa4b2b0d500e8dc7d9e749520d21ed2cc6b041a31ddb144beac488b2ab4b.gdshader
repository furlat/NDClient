shader_type spatial;
uniform mat4 factory_world_to_source=mat4(1.0);
uniform float factory_occurrence_alpha=1.0;

varying float flame_rise;

uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_tex:source_color;uniform vec4 source_tint:source_color=vec4(1.0);varying float steam_frame;void vertex(){float birth = 0.08 + clamp(dot(MODEL_MATRIX[3].xz, vec2(0.70710678118655,0.70710678118655)) * 0.23 + 0.28,0.0,0.6); float rising=smoothstep(birth,birth+0.55,support_age); flame_rise=rising; VERTEX.y *= max(0.008,rising);
steam_frame=INSTANCE_CUSTOM.z;vec3 up=vec3(0.0,1.0,0.0);vec3 right=normalize(INV_VIEW_MATRIX[0].xyz);vec3 forward=normalize(cross(right,up));mat4 bb=mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(forward*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);MODELVIEW_MATRIX=VIEW_MATRIX*bb;}void fragment(){
vec3 support_world=(factory_world_to_source * INV_VIEW_MATRIX * vec4(VERTEX,1.0)).xyz;

vec4 c=texture(source_tex,(UV+vec2(mod(clamp(floor(steam_frame*64.0),0.0,63.0),8.0),floor(clamp(floor(steam_frame*64.0),0.0,63.0)/8.0)))/vec2(8.0,8.0))*source_tint*COLOR;ALBEDO=c.rgb*0.7;ALPHA=c.a;
ALPHA *= support_envelope;
ALPHA *= smoothstep(0.12,0.38,flame_rise);
ALBEDO=vec3(clamp(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))*0.65,0.05,0.85));EMISSION=vec3(0.0);

ALPHA *= factory_occurrence_alpha;
}



