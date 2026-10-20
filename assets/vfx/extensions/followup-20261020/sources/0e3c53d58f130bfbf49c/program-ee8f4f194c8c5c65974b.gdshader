shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
uniform float support_age=0.0;render_mode unshaded,cull_disabled,depth_draw_never;uniform sampler2D source_tex:source_color;uniform vec4 source_tint:source_color=vec4(1.0);void fragment(){
vec4 c=texture(source_tex,UV)*source_tint*COLOR;ALBEDO=c.rgb*0.7;ALPHA=c.a;
ALPHA *= support_envelope;
}



