shader_type canvas_item;
render_mode blend_disabled;
// Original native composition fields. Source colour stays in its own pass;
// only Godot Canvas lights accumulate here, exactly like the game atlas.
uniform sampler2D native_colour : filter_nearest, repeat_disable;
uniform sampler2D native_normals : filter_nearest, repeat_disable;
uniform sampler2D native_material : filter_nearest, repeat_disable;
vec3 source_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
void fragment() {
    vec4 colour=texture(native_colour,UV);
    if(colour.a<=0.0)discard;
    vec4 field=texture(native_normals,UV);
    vec3 packed=source_decode(field.rgb)/max(field.a,1.0/65535.0);
    vec3 normal=normalize(packed*2.0-1.0);
    NORMAL=vec3(normal.x,-normal.y,normal.z);
    COLOR=vec4(1.0,1.0,1.0,colour.a);
}
