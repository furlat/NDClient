shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2DArray frames : source_color, filter_nearest, repeat_disable;
uniform int frame_index = 0;
void fragment() {
    vec4 colour = texture(frames,vec3(UV,float(frame_index)));
    if (colour.a <= 0.0) discard;
    ALBEDO = colour.rgb;
    ALPHA = colour.a;
}
