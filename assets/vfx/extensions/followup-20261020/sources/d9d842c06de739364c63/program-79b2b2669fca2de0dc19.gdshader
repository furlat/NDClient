shader_type spatial;
uniform float support_clock=0.0;
uniform float support_envelope=1.0;
render_mode unshaded,cull_disabled;
// curse_brand_marker
uniform sampler2D mark_noise;
float stroke(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));}
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=(UV-vec2(0.5))*vec2(1.0,-1.2);
 float d=stroke(p,vec2(0.035,-0.46),vec2(-0.025,-0.06));
 d=min(d,stroke(p,vec2(-0.025,-0.06),vec2(-0.04,0.12)));
 d=min(d,stroke(p,vec2(-0.04,0.12),vec2(-0.27,0.31)));
 d=min(d,stroke(p,vec2(-0.27,0.31),vec2(-0.22,0.48)));
 d=min(d,stroke(p,vec2(-0.04,0.12),vec2(0.28,0.43)));
 d=min(d,stroke(p,vec2(-0.27,-0.17),vec2(0.2,-0.27)));
 float core=1.0-smoothstep(0.04,0.047,d);
 float rim=1.0-smoothstep(0.062,0.072,d);
 ALBEDO=mix(vec3(0.045,0.015,0.025),vec3(1.0,0.035,0.07),core);
 float mottling=texture(mark_noise,UV*1.5+vec2(support_clock/6.0,-support_clock/3.0)).r;
 ALBEDO*=mix(0.48,1.0,smoothstep(0.2,0.8,mottling));
 ALPHA=rim;

ALPHA *= min(1.0,support_envelope*1.5);
}


