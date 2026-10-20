shader_type spatial;
uniform float factory_occurrence_alpha=1.0;

render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The purchased 5x5 fire animation stays intact. Its particle quads face the
// camera but their LONG axis follows the real current blade, not world up.
uniform sampler2D source_flipbook : source_color, filter_linear, repeat_disable;
uniform vec3 blade_axis_world = vec3(0.0, 1.0, 0.0);
uniform float lateral_scale = 0.48;
uniform float axial_scale = 1.35;
uniform float colour_gain = 1.0;
varying vec2 flipbook_uv;

void vertex() {
    vec3 toward = INV_VIEW_MATRIX[2].xyz;
    vec3 projected = blade_axis_world - toward * dot(toward, blade_axis_world);
    if (length(projected) < 0.0001) projected = INV_VIEW_MATRIX[1].xyz;
    projected = normalize(projected);
    vec3 across = normalize(cross(projected, toward));
    float sx = length(MODEL_MATRIX[0].xyz) * lateral_scale;
    float sy = length(MODEL_MATRIX[1].xyz) * axial_scale;
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(across * sx, 0.0),
        vec4(projected * sy, 0.0), vec4(toward, 0.0), MODEL_MATRIX[3]);
    // Native particle process anim_speed controls the source flipbook clock.
    float cell = clamp(floor(INSTANCE_CUSTOM.z * 25.0), 0.0, 24.0);
    flipbook_uv = (UV + vec2(mod(cell, 5.0), floor(cell / 5.0))) / 5.0;
}

void fragment() {
    vec4 source = texture(source_flipbook, flipbook_uv);
    float intensity = max(source.r, max(source.g, source.b));
    vec3 warm = mix(vec3(0.45, 0.012, 0.001), vec3(1.0, 0.43, 0.016),
        smoothstep(0.06, 0.88, intensity));
    // True coverage, no opaque black carrier and no white clipping/bloom lamp.
    ALBEDO = warm * colour_gain;
    ALPHA = source.a * COLOR.a;

ALPHA *= factory_occurrence_alpha;
}



