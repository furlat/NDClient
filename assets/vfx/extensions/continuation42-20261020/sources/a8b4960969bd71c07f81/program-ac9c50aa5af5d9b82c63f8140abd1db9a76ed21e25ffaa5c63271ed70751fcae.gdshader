shader_type spatial;
global uniform sampler2D vfx_package_clock;
uniform int vfx_package_clock_slot=0;
float vfx_package_seconds(){return texelFetch(vfx_package_clock,ivec2(vfx_package_clock_slot,0),0).r;}
uniform float vfx_package_offset_clock=0.0;

render_mode unshaded,cull_disabled;
uniform sampler2D bark: source_color,repeat_enable;
uniform float clock=0.0;
uniform float opacity=1.0;
uniform float seed=0.0;
varying vec3 norm;
void vertex(){
 norm=NORMAL;
 // Anchored roots with visible, differently phased tip flex on the export grid.
 float tip=pow(clamp(VERTEX.y/.32,0.0,1.0),1.4);
 VERTEX.x+=sin((vfx_package_seconds()+vfx_package_offset_clock)*3.14159265+seed+VERTEX.y*4.0)*.065*tip;
 VERTEX.z+=cos((vfx_package_seconds()+vfx_package_offset_clock)*3.14159265+seed*1.7)*.044*tip;
}
void fragment(){
 float t=texture(bark,UV*vec2(1.0,2.0)).r;
 float lit=max(dot(normalize(norm),normalize(vec3(-.3,1.,.8))),0.0);
 vec3 c=mix(vec3(.018,.012,.008),vec3(.27,.17,.07),clamp(t*.15+lit*.8,0.,1.));
 ALBEDO=c;ALPHA=opacity;
}


