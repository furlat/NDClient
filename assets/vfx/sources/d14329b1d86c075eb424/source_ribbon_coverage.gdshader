shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, particle_trails, shadows_disabled, fog_disabled;

// LeLu Weapon Effects' original T_VFX_f32 pattern is opaque RGBA, including
// black. Its original additive-on-black presentation hides that carrier. The
// game's separate transparent colour pass needs explicit mask coverage.
uniform sampler2D source_pattern : source_color, filter_linear, repeat_disable;
uniform float source_gain = 0.6;

void fragment() {
    float coverage = texture(source_pattern, UV).r;
    if (coverage <= 0.0001) discard;
    ALBEDO = COLOR.rgb * source_gain;
    ALPHA = coverage * COLOR.a;
}
