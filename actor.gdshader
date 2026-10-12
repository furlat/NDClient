shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_uv;
void fragment() {
    vec4 colour = texture(sheet, frame_uv.xy + UV * frame_uv.zw);
    if (colour.a <= 0.0) { discard; }
    ALBEDO = colour.rgb;
    EMISSION = colour.rgb;
    ALPHA = colour.a;
    ROUGHNESS = 1.0;
}
