shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_uv;
uniform float shadow_alpha;
void fragment() {
    vec4 colour = texture(sheet, frame_uv.xy + UV * frame_uv.zw);
    ALBEDO = colour.rgb;
    ALPHA = colour.a * shadow_alpha;
}
