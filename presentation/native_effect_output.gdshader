shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D effect_texture : source_color, filter_nearest, repeat_disable;
uniform bool receiving_enabled = false;
uniform sampler2D receiving_texture : filter_nearest, repeat_disable;
uniform float light_cap = 0.0;
vec3 source_encode(vec3 value) {
    return mix(1.055*pow(value,vec3(1.0/2.4))-vec3(.055),12.92*value,lessThanEqual(value,vec3(.0031308)));
}
vec3 source_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
uniform float opacity = 1.0;
void fragment() {
    vec4 value=texture(effect_texture,UV);
    if(receiving_enabled) {
        vec3 light=texture(receiving_texture,UV).rgb;
        float peak=max(light.r,max(light.g,light.b));
        if(light_cap>0.0 && peak>light_cap)light*=light_cap/peak;
        vec3 original=source_encode(clamp(value.rgb/max(value.a,1.0/65535.0),vec3(0.0),vec3(1.0)));
        ALBEDO=source_decode(clamp(original*light,vec3(0.0),vec3(1.0)));
    } else ALBEDO=value.rgb;
    ALPHA=value.a*opacity;
}
