shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
// Port of the connected branches in the existing water material graph, lit in
// its own pass with the receiving rules of the former light atlas: each texel
// is lit once at its screen centre on the painted plane, normal straight up.
#include "res://presentation/source_colour_water.gdshaderinc"
#include "res://presentation/lit_receiving.gdshaderinc"
uniform float current_visibility : hint_range(0.0, 1.0) = 1.0;
varying vec2 instance_shift;
void vertex() {
    instance_shift = water_source_shift(MODEL_MATRIX[3].xyz);
    mat3 screen = lit_screen_quad(VERTEX, UV, PROJECTION_MATRIX * MODELVIEW_MATRIX);
    source_screen_origin = screen[0].xy; source_screen_axis_x = screen[1].xy; source_screen_axis_y = screen[2].xy;
}
void fragment() {
    vec2 texel = lit_texel_uv(UV, cell);
    vec2 screen = lit_screen_uv(texel);
    vec4 colour = water_source_colour(texel, instance_shift, screen, current_visibility);
    if (colour.a <= 0.0) { discard; }
    float alpha = lit_stored_alpha(colour.a);
    if (alpha <= 0.0 || wall_opacity <= 0.0) { discard; }
    vec3 normal = normalize(lit_world_to_canvas(INV_VIEW_MATRIX) * vec3(0.0, 1.0, 0.0));
    colour.rgb = light_normals ? lit_unlit(normal * 0.5 + 0.5) : lit_received(colour.rgb, screen * VIEWPORT_SIZE, normal);
    ALBEDO = lit_albedo(colour.rgb, OUTPUT_IS_SRGB);
    ALPHA = alpha * wall_opacity;
}
