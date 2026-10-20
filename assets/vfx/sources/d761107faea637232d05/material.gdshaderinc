#ifndef FACTORY_PURE_WEAPON_MATERIAL_INCLUDED
#define FACTORY_PURE_WEAPON_MATERIAL_INCLUDED
// Fully elemental RGB on the ACTUAL weapon sheet. The caller alone owns source
// alpha, current optical frame/depth/valid normals, draw order and private clock.
// No original steel is mixed into an admitted blade, including lesser strength.
uniform bool weapon_pure_enabled = false;
uniform bool weapon_pure_axis_valid = false;
uniform int weapon_pure_kind = 1; // 1 stationary ice, 2 live lightning
uniform int weapon_pure_variant = 0;
uniform float weapon_pure_seconds = 0.0;
uniform float weapon_pure_strength : hint_range(0.0, 1.0) = 0.74;
uniform vec4 weapon_pure_hilt_tip = vec4(0.0);
uniform float weapon_pure_half_width_uv = 0.025;
uniform float weapon_pure_grip_end : hint_range(0.0, 0.8) = 0.04;
uniform sampler2D weapon_pure_cells : filter_linear, repeat_enable;
uniform sampler2D weapon_pure_arc_sheet : filter_linear, repeat_disable;
uniform vec3 weapon_pure_dark : source_color = vec3(0.025, 0.13, 0.24);
uniform vec3 weapon_pure_body : source_color = vec3(0.16, 0.51, 0.72);
uniform vec3 weapon_pure_core : source_color = vec3(0.58, 0.88, 0.94);
uniform vec3 weapon_pure_accent : source_color = vec3(0.32, 0.68, 0.83);

vec2 weapon_pure_coordinates(vec2 frame_uv) {
    vec2 axis = weapon_pure_hilt_tip.zw - weapon_pure_hilt_tip.xy;
    float span = max(length(axis), 0.00001);
    vec2 direction = axis / span;
    vec2 offset = frame_uv - weapon_pure_hilt_tip.xy;
    return vec2(dot(offset, vec2(-direction.y, direction.x))
        / max(weapon_pure_half_width_uv, 0.00001), dot(offset, direction) / span);
}

float weapon_pure_coverage(vec2 frame_uv) {
    if (!weapon_pure_enabled || !weapon_pure_axis_valid) return 0.0;
    if (weapon_pure_kind != 1 && weapon_pure_kind != 2) return 0.0;
    if (length(weapon_pure_hilt_tip.zw - weapon_pure_hilt_tip.xy) < 0.00001)
        return 0.0;
    vec2 blade = weapon_pure_coordinates(frame_uv);
    // This is a grip/admission gate, NOT source alpha or a reconstructed blade.
    // Do not clip a curved Scimitar to a guessed straight-line lateral radius.
    return step(weapon_pure_grip_end, blade.y);
}

float weapon_pure_native_forks(vec2 blade, float phase) {
    // LeLu Weapon Effects' original four native branching masks. Interpolate
    // neighbouring cells; do not blink a whole blade or draw a generic zigzag.
    float clock = weapon_pure_seconds * 2.25 + phase;
    float current = floor(clock);
    float blend = smoothstep(0.12, 0.88, fract(clock));
    float frame_a = mod(current, 4.0);
    float frame_b = mod(current + 1.0, 4.0);
    vec2 uv = vec2(clamp(0.5 + blade.x * 0.23, 0.005, 0.995),
        clamp(blade.y, 0.005, 0.995));
    vec2 cell_a = vec2(mod(frame_a, 2.0), floor(frame_a / 2.0));
    vec2 cell_b = vec2(mod(frame_b, 2.0), floor(frame_b / 2.0));
    vec4 first = texture(weapon_pure_arc_sheet, (cell_a + uv) * 0.5);
    vec4 second = texture(weapon_pure_arc_sheet, (cell_b + uv) * 0.5);
    return mix(first.r * first.a, second.r * second.a, blend);
}

vec3 weapon_pure_crystal(vec2 blade, vec3 normal) {
    // Binbun IceVFX ice_shard_01_core uses cellular masks + overlay breakup.
    // Two samples of the actual native cell field remain fixed to the weapon.
    // There is NO time input, moving lattice, wobble, vertex growth or steel.
    vec2 uv = vec2(blade.x * 0.18, blade.y * 2.15);
    float broad = texture(weapon_pure_cells, uv).r;
    float detail = texture(weapon_pure_cells,
        uv * vec2(1.73, 1.41) + vec2(0.37, 0.16)).r;
    float overlay = mix(2.0 * broad * detail,
        1.0 - 2.0 * (1.0 - broad) * (1.0 - detail), step(0.5, broad));
    float facets = smoothstep(0.18, 0.76, overlay);
    float facing = clamp(abs(normal.z), 0.0, 1.0);
    float bevel = clamp(abs(normal.x) * 0.7 + abs(normal.y) * 0.3, 0.0, 1.0);
    float frost_edge = pow(1.0 - facing, 1.8);
    // Coarse longitudinal faces survive a two-to-four-pixel source blade;
    // repeated tiny cells alone collapse to the same average cyan as rime.
    float face = smoothstep(-0.15, 0.15, blade.x + (broad - 0.5) * 0.32);
    vec3 ice = mix(weapon_pure_dark, weapon_pure_body,
        0.16 + face * 0.56 + facets * 0.18);
    float sharp = smoothstep(0.57, 0.82, detail) * (0.18 + 0.36 * weapon_pure_strength);
    ice = mix(ice, weapon_pure_core,
        clamp(sharp + frost_edge * 0.28 + bevel * 0.20, 0.0, 0.78));
    return ice;
}

vec3 weapon_pure_rime(vec2 blade, vec3 normal) {
    // A different physical finish: opaque frozen mass with fixed branching
    // dark fracture channels and lighter frost on its faces, not clear steel.
    vec2 uv = vec2(blade.x * 0.15, blade.y * 1.75);
    float cells = texture(weapon_pure_cells, uv).r;
    float fine = texture(weapon_pure_cells,
        uv * vec2(2.7, 2.1) + vec2(0.18, 0.63)).r;
    float fracture = 1.0 - smoothstep(0.018, 0.095, abs(cells - 0.49));
    float branch = (1.0 - smoothstep(0.025, 0.08, abs(fine - 0.51)))
        * smoothstep(0.29, 0.66, cells);
    float channels = max(fracture, branch * 0.72);
    float bevel = clamp(abs(normal.x) * 0.65 + abs(normal.y) * 0.35, 0.0, 1.0);
    vec3 ice = mix(weapon_pure_body, weapon_pure_core,
        0.32 + fine * 0.30 + bevel * (0.16 + 0.18 * weapon_pure_strength));
    ice = mix(ice, weapon_pure_dark,
        channels * (0.45 + 0.38 * weapon_pure_strength));
    return ice;
}

vec3 weapon_pure_conduit(vec2 blade, vec3 normal) {
    // Boringdev actual LightningBolt/blue-yellow derivative: separate soft
    // halo, denser core, very narrow hot centre and TWO frequency flow fields.
    // Work in real weapon coordinates, not a replacement 3D bolt mesh. Omit
    // the original repeated white/HDR additions. Source alpha owns the shape.
    vec2 uv = vec2(blade.x * 0.18, blade.y * 3.5 - weapon_pure_seconds * 1.6);
    float noise_a = texture(weapon_pure_cells, uv).r;
    float noise_b = texture(weapon_pure_cells,
        uv * 2.3 + vec2(0.37, -weapon_pure_seconds * 1.6 * 1.9)).r;
    float flow = 0.55 + 0.9 * mix(noise_a, noise_b, 0.5);
    float edge = 1.0 - smoothstep(0.04, 1.4, abs(blade.x));
    float halo = pow(edge, 1.1);
    float core = pow(edge, 2.4) * (0.7 + 0.55 * flow);
    float hot = pow(edge, 4.6) * (0.45 + 1.25 * flow);
    float forks = pow(clamp(weapon_pure_native_forks(blade, 0.0), 0.0, 1.0), 0.70);
    float bevel = clamp(abs(normal.x) * 0.6 + abs(normal.y) * 0.4, 0.0, 1.0);
    // A connected coloured body exists at every strength and flow phase.
    vec3 charge = mix(weapon_pure_dark, weapon_pure_body,
        0.56 + 0.24 * halo + 0.08 * bevel);
    charge = mix(charge, weapon_pure_core,
        clamp((core * 0.28 + hot * 0.08 + forks * 0.36)
            * (0.62 + 0.38 * weapon_pure_strength), 0.0, 0.83));
    float warm = smoothstep(0.92, 1.0, forks) * smoothstep(0.74, 0.98, noise_b);
    return mix(charge, weapon_pure_accent, warm * 0.055 * weapon_pure_strength);
}

vec3 weapon_pure_storm(vec2 blade, vec3 normal) {
    // Braided native branching discharge instead of the conduit's central
    // core. Opposing source fields cross within the real source blade mask.
    vec2 uv = vec2(blade.x * 0.26, blade.y * 2.1);
    float broad = texture(weapon_pure_cells,
        uv - vec2(0.0, weapon_pure_seconds * 0.72)).r;
    float fine = texture(weapon_pure_cells,
        uv * 2.3 + vec2(0.43, weapon_pure_seconds * 0.51)).r;
    vec2 first_uv = vec2(blade.x + (broad - 0.5) * 0.52, blade.y);
    vec2 second_uv = vec2(-blade.x * 1.15 + (fine - 0.5) * 0.42,
        1.0 - blade.y);
    float first = weapon_pure_native_forks(first_uv, 0.0);
    float second = weapon_pure_native_forks(second_uv, 1.7);
    float network = pow(clamp(max(first, second * 0.88), 0.0, 1.0), 0.67);
    float body = smoothstep(0.12, 0.80, broad * 0.58 + fine * 0.42);
    float bevel = clamp(abs(normal.x) * 0.6 + abs(normal.y) * 0.4, 0.0, 1.0);
    vec3 charge = mix(weapon_pure_dark, weapon_pure_body,
        0.48 + body * 0.38 + bevel * 0.08);
    charge = mix(charge, weapon_pure_core,
        clamp(network * (0.58 + weapon_pure_strength * 0.34), 0.0, 0.90));
    float warm = smoothstep(0.89, 0.99, min(first, second))
        * smoothstep(0.71, 0.95, fine);
    return mix(charge, weapon_pure_accent, warm * 0.24 * weapon_pure_strength);
}

vec3 weapon_pure_colour(vec3 original_rgb, vec2 frame_uv, vec3 current_valid_normal) {
    if (weapon_pure_coverage(frame_uv) < 0.5) return original_rgb;
    vec2 blade = weapon_pure_coordinates(frame_uv);
    vec3 colour = weapon_pure_body;
    if (weapon_pure_kind == 1 && weapon_pure_variant == 0)
        colour = weapon_pure_crystal(blade, current_valid_normal);
    else if (weapon_pure_kind == 1 && weapon_pure_variant == 1)
        colour = weapon_pure_rime(blade, current_valid_normal);
    else if (weapon_pure_kind == 2 && weapon_pure_variant == 0)
        colour = weapon_pure_conduit(blade, current_valid_normal);
    else if (weapon_pure_kind == 2 && weapon_pure_variant == 1)
        colour = weapon_pure_storm(blade, current_valid_normal);
    return clamp(colour, vec3(0.0), vec3(1.0));
}
#endif
