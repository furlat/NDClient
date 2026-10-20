shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){
float a=0.5+0.5*sin(UV.x*29.0-support_clock*3.14159265);ALBEDO=vec3(0.48+0.42*a);ALPHA=0.88;
ALPHA *= support_envelope;
}



