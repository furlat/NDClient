shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
// Authored LeLu smoke mesh and tiled dissolve texture, adapted lifecycle.
uniform sampler2D Disolver_Texture;
uniform float puff_life=0.0;
void fragment(){
	vec2 uv=UV*0.75+vec2(support_clock/6.0,-support_clock/3.0);
	float n=texture(Disolver_Texture,uv).r;
	float detail=texture(Disolver_Texture,UV*1.9+vec2(-support_clock/3.0,support_clock/6.0)).r;
	float erosion=mix(0.30,0.94,pow(puff_life,0.8));
	float body=smoothstep(erosion,erosion+0.14,n)*smoothstep(0.16,0.39,detail);
	float lit_edge=1.0-smoothstep(erosion+0.14,erosion+0.30,n);
	ALBEDO=mix(vec3(0.065,0.01,0.024),vec3(0.56,0.025,0.055),lit_edge*mix(0.35,1.0,detail));
	ALPHA=body*smoothstep(0.0,0.16,puff_life)*(1.0-smoothstep(0.66,1.0,puff_life))*0.48;

ALPHA *= support_envelope * 0.6;
}


