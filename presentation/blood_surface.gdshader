shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never,depth_test_disabled;
#include "res://presentation/blood_liquid.gdshaderinc"
#include "res://presentation/source_colour_common.gdshaderinc"
uniform sampler2D field_texture:filter_nearest,repeat_disable;
uniform sampler2D illumination:filter_nearest,repeat_disable;
uniform vec2 tile_position;
uniform float light_cap=0.;
uniform float visibility=1.;
uniform bool normals_visible=false;
uniform vec3 receiving_normal;
vec3 decode(vec3 value){return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));}
void fragment(){
    vec2 texel=(floor(UV*64.)+.5)/64.;
    vec4 original=blood_liquid(texture(field_texture,texel).r,tile_position+texel-.5);
    if(original.a<=0.)discard;
    vec3 light=texture(illumination,SCREEN_UV).rgb;float peak=max(light.r,max(light.g,light.b));if(light_cap>0.&&peak>light_cap)light*=light_cap/peak;
    ALBEDO=decode(normals_visible?receiving_normal*.5+.5:clamp(source_remembered_colour(original.rgb,visibility)*light,vec3(0.),vec3(1.)));
    ALPHA=original.a;
}
