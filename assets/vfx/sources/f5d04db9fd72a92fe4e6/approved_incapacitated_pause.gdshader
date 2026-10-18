shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://assets/vfx/sources/eb06cc2929dc57d35d5b/cie_d65_v1.gdshaderinc"
uniform float glyph_clock=0.0;

// Steady held form of the accepted 2026-10-01 two-bar preview drawing.
// Native vector coverage retains its original gold shadow and cream cores.
float pause_box(vec2 p,vec2 lower,vec2 upper){
	vec2 inside=min(p-lower,upper-p);
	return smoothstep(-.30,.30,min(inside.x,inside.y));
}

void fragment(){
	vec2 p=UV*16.-vec2(8.,0.);
	float shadow=max(pause_box(p,vec2(-6.,1.),vec2(-2.,14.)),pause_box(p,vec2(2.,1.),vec2(6.,14.)));
	float core=max(pause_box(p,vec2(-5.,0.),vec2(-3.,11.)),pause_box(p,vec2(3.,0.),vec2(5.,11.)));
	vec3 encoded=mix(vec3(153.,107.,48.)/255.,vec3(255.,240.,191.)/255.,core);
	ALBEDO=vec3(cie_linear_channel(encoded.r),cie_linear_channel(encoded.g),cie_linear_channel(encoded.b));
	ALPHA=max(shadow,core);
}
