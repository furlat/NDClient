shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D bark: source_color,repeat_enable;
uniform float clock=0.0;
uniform float opacity=1.0;
uniform float seed=0.0;
varying vec3 norm;
void vertex(){
 norm=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 // Anchored roots with visible, differently phased tip flex on the export grid.
 float tip=pow(clamp(VERTEX.y/.32,0.0,1.0),1.4);
 VERTEX.x+=sin(clock*3.14159265+seed+VERTEX.y*4.0)*.065*tip;
 VERTEX.z+=cos(clock*3.14159265+seed*1.7)*.044*tip;
}
void fragment(){
 float t=texture(bark,UV*vec2(1.0,2.0)).r;
 float lit=max(dot(normalize(norm),normalize(vec3(-.3,1.,.8))),0.0);
 vec3 c=mix(vec3(.018,.012,.008),vec3(.38,.245,.105),clamp(t*.15+lit*.8,0.,1.));
 ALBEDO=c;ALPHA=opacity;
}
