uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform vec3 tint = vec3(1.0);
uniform float layer_alpha = 1.0;
uniform bool shadow = false;
vec4 modular_source_colour(vec2 uv) {
    vec4 colour = texture(sheet, frame_uv.xy + uv * frame_uv.zw);
    colour.rgb *= tint;
    return vec4(shadow ? vec3(0.0) : colour.rgb, colour.a * layer_alpha);
}
