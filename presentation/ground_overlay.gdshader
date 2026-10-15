shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// These ground marks use the same painter ranks as the sprites. They neither
// receive lighting nor change source artwork or the support's physical height.
uniform vec4 line_colour : source_color = vec4(0.56,0.70,0.85,0.12);
uniform float line_width_pixels = 1.0;
uniform vec4 fill_colour : source_color = vec4(0.0);
void fragment() {
    vec2 edge_pixels = min(UV,vec2(1.0)-UV)/max(fwidth(UV),vec2(0.000001));
    float coverage = 1.0-smoothstep(line_width_pixels*0.5-0.5,line_width_pixels*0.5+0.5,min(edge_pixels.x,edge_pixels.y));
    float edge_alpha = line_colour.a*coverage;
    float fill_alpha = fill_colour.a*(1.0-edge_alpha);
    ALPHA = edge_alpha+fill_alpha;
    ALBEDO = (line_colour.rgb*edge_alpha+fill_colour.rgb*fill_alpha)/max(ALPHA,0.000001);
}
