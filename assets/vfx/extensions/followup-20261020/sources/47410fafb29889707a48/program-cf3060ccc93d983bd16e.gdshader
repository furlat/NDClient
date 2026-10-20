shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
uniform sampler2D source_noise:repeat_enable;
void fragment(){float n=texture(source_noise,UV*2.).r;ALBEDO=vec3(.035+.52*step(.72,n));ALPHA=.92;
ALPHA *= support_envelope;
}




