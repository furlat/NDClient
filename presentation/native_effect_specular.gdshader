shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D native_material : filter_nearest, repeat_disable;
vec3 decode_source(vec3 v){return mix(pow((v+vec3(.055))/1.055,vec3(2.4)),v/12.92,lessThanEqual(v,vec3(.04045)));}
void fragment(){
    vec4 field=texture(native_material,UV);
    vec3 properties=decode_source(field.rgb)/max(field.a,1.0/65535.0);
    COLOR=field.a>0.0 ? vec4(vec3(clamp(properties.b,0.0,1.0)),1.0-clamp(properties.r,0.0,1.0)) : vec4(0.0);
}
