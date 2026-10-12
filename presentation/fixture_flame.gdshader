shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2DArray frames : source_color, filter_nearest, repeat_disable;
uniform int frame_index = 0;
// The registered torch sequence has an alpha-1 padding pedestal. Zero keeps
// other authored effects unchanged; remove only that measured floor, smoothly.
uniform float alpha_pedestal = 0.0;
void fragment() {
    vec4 colour = texture(frames,vec3(UV,float(frame_index)));
    colour.a = max(0.0, (colour.a - alpha_pedestal) / (1.0 - alpha_pedestal));
    if (colour.a <= 0.0) discard;
    ALBEDO = colour.rgb;
    ALPHA = colour.a;
}
