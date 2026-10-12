shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D visibility_map : filter_nearest, repeat_disable;
uniform sampler2D cookie_atlas : filter_linear, repeat_disable;
uniform sampler2D source_data : filter_nearest, repeat_disable;
uniform int source_count=0;
uniform int dominant_index=-1;
uniform float core_opacity=0.8392156862745098;

float cookie(int i,vec2 screen) {
    vec4 projection=texelFetch(source_data,ivec2(0,i),0);
    vec2 uv=(screen-projection.xy)/projection.zw+0.5;
    if(any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) return 0.0;
    vec4 rect=texelFetch(source_data,ivec2(1,i),0);
    vec4 value=texture(cookie_atlas,rect.xy+uv*rect.zw);
    return max(value.r,max(value.g,value.b))*value.a;
}
void fragment() {
    if(dominant_index<0 || dominant_index>=source_count) discard;
    float blocked=1.0-texture(visibility_map,UV).r;
    if(blocked<=0.0) discard;
    vec2 screen=SCREEN_UV*VIEWPORT_SIZE;
    float total=0.0;
    float selected_weight=0.0;
    float selected_cookie=0.0;
    for(int i=0;i<source_count;i++) {
        float gate=cookie(i,screen);
        float weight=gate*texelFetch(source_data,ivec2(2,i),0).r;
        total+=weight;
        if(i==dominant_index) { selected_weight=weight; selected_cookie=gate; }
    }
    if(total<=0.00000001) discard;
    // Dominant casts once; every enabled source supplies its unblocked share.
    // Multiplication preserves the underlying terrain texture and colour.
    float opacity=core_opacity*blocked*selected_cookie*selected_weight/total;
    if(opacity<=0.0) discard;
    // Native black source-over is exactly ground * (1 - opacity). Unlike
    // blend_mul ALBEDO factors, alpha is outside the engine color transfer.
    ALBEDO=vec3(0.0);
    ALPHA=opacity;
}
