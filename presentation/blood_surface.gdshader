shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never,depth_test_disabled;
#include "res://presentation/blood_liquid.gdshaderinc"
#include "res://presentation/source_colour_common.gdshaderinc"
#include "res://presentation/blood_receiving.gdshaderinc"
// One atlas page per material; each stain reads its own 64x64 slot.
uniform sampler2D field_atlas:filter_nearest,repeat_disable;
instance uniform vec2 field_origin;
instance uniform vec2 tile_position;
instance uniform float visibility=1.;
instance uniform bool fragment_primitive=false;
instance uniform bool authored_palette=false;
instance uniform vec3 palette0=vec3(0.);
instance uniform vec3 palette1=vec3(0.);
instance uniform vec3 palette2=vec3(0.);
uniform float light_cap=0.;
uniform bool normals_visible=false;
uniform vec3 receiving_normal;
vec3 decode(vec3 value){return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));}
void fragment(){
    vec2 cell=floor(UV*64.);vec2 texel=(cell+.5)/64.;
    ivec2 sample_cell=ivec2(field_origin+cell);
    float field=texelFetch(field_atlas,sample_cell,0).r;
    vec4 original;
    if(fragment_primitive){
        bool inside=field>=.5;
        ivec2 x_before=ivec2(field_origin)+ivec2((int(cell.x)+63)%64,int(cell.y));
        ivec2 y_before=ivec2(field_origin)+ivec2(int(cell.x),(int(cell.y)+63)%64);
        bool edge=inside&&!(texelFetch(field_atlas,x_before,0).r>=.5&&texelFetch(field_atlas,y_before,0).r>=.5);
        original=vec4(edge?palette2:palette1,inside?240./255.:0.);
    }else if(authored_palette){
        original=blood_palette_liquid(field,tile_position+texel-.5,palette0,palette1,palette2);
    }else{
        original=blood_liquid(field,tile_position+texel-.5);
    }
    if(original.a<=0.)discard;
    vec3 light=blood_irradiance(SCREEN_UV,VIEWPORT_SIZE,receiving_normal);float peak=max(light.r,max(light.g,light.b));if(light_cap>0.&&peak>light_cap)light*=light_cap/peak;
    ALBEDO=decode(normals_visible?receiving_normal*.5+.5:clamp(source_remembered_colour(original.rgb,visibility)*light,vec3(0.),vec3(1.)));
    ALPHA=original.a;
}
