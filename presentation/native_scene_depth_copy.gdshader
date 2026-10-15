shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D receiver_depth:filter_nearest,repeat_disable;
void vertex(){
    POSITION=vec4(VERTEX.xy,1.0,1.0);
}
void fragment(){
    vec4 support=texelFetch(receiver_depth,ivec2(FRAGCOORD.xy),0);
    if(support.a<=.5)discard;
    vec3 bytes=round(support.rgb*255.);
    DEPTH=dot(bytes,vec3(65536.,256.,1.))/16777215.;
    ALBEDO=support.rgb;
}
