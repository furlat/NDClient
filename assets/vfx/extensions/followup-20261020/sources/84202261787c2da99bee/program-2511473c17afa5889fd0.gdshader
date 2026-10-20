shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
// curse_brand_marker
uniform float tear_alpha=1.0;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
	vec2 p=UV-vec2(0.5);
	float width=mix(0.07,0.44,smoothstep(-0.4,0.22,p.y));
	float edge=(1.0-smoothstep(width-0.07,width,abs(p.x)))*(1.0-smoothstep(0.29,0.48,p.y))*smoothstep(-0.5,-0.3,p.y);
	ALBEDO=mix(vec3(0.23,0.012,0.025),vec3(0.72,0.025,0.04),1.0-smoothstep(0.02,0.3,abs(p.x)));
	ALPHA=edge*tear_alpha;

ALPHA *= min(1.0,support_envelope*1.5);
}


