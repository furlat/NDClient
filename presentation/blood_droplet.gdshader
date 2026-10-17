shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never,depth_test_disabled;
#include "res://presentation/blood_receiving.gdshaderinc"
uniform float light_cap=0.;
uniform bool normals_visible=false;
uniform bool partition=false;
uniform bool back=false;
uniform vec3 plane_origin;
uniform vec3 plane_normal;
varying vec3 world_point;
varying vec4 tint;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;tint=COLOR;}
vec3 decode(vec3 value){return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));}
void fragment(){
    if(!partition&&back)discard;
    if(partition&&(dot(world_point-plane_origin,plane_normal)<0.)!=back)discard;
    vec3 light=blood_irradiance(SCREEN_UV,VIEWPORT_SIZE,vec3(0.,0.,1.));float peak=max(light.r,max(light.g,light.b));if(light_cap>0.&&peak>light_cap)light*=light_cap/peak;
    ALBEDO=decode(normals_visible?vec3(.5,.5,1.):clamp(tint.rgb*light,vec3(0.),vec3(1.)));ALPHA=tint.a;
}
