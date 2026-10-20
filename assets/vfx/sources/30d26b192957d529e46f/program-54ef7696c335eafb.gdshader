shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_support_clock=0.0;

uniform float support_clock=0.0;
uniform float support_envelope=1.0; render_mode unshaded,cull_disabled; uniform vec4 flower_color:source_color=vec4(1.0); uniform sampler2D tex:source_color; void fragment(){vec4 c=texture(tex,UV)*flower_color; ALBEDO=c.rgb; ALPHA=c.a;
ALPHA *= support_envelope;
}

