shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,depth_test_disabled,shadows_disabled;
uniform sampler2D sheet:source_color,filter_nearest,repeat_disable;
uniform vec4 frame_uv=vec4(0.0,0.0,1.0,1.0);
uniform float opacity=1.0;
void fragment(){vec4 c=texture(sheet,frame_uv.xy+UV*frame_uv.zw);ALBEDO=c.rgb;ALPHA=c.a*opacity;}
