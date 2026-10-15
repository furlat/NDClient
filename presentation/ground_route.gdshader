shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 line_colour : source_color;
uniform vec3 line_from;
uniform vec3 line_to;
uniform float line_width_pixels = 2.0;
void vertex() {
    vec4 a = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(line_from,1.0);
    vec4 b = PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(line_to,1.0);
    vec2 direction = (b.xy/b.w-a.xy/a.w)*VIEWPORT_SIZE;
    vec2 perpendicular = normalize(vec2(-direction.y,direction.x));
    POSITION = mix(a,b,UV.x);
    POSITION.xy += perpendicular*(UV.y-0.5)*line_width_pixels*2.0/VIEWPORT_SIZE*POSITION.w;
}
void fragment() {
    ALBEDO = line_colour.rgb;
    ALPHA = line_colour.a;
}
