shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0; render_mode unshaded,cull_disabled; void fragment(){ALBEDO=vec3(0.76,0.56,0.24);ALPHA=0.6;
ALPHA *= support_envelope;
}


