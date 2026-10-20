#ifndef FACTORY_WEAPON_ELEMENT_STUDY_INCLUDED
#define FACTORY_WEAPON_ELEMENT_STUDY_INCLUDED
// Material-only study. The owning weapon draw keeps its original ALPHA, depth,
// normals and frame. No hidden sword pixels or complete sword axis are inferred.
uniform bool weapon_element_enabled = false;
uniform bool weapon_element_axis_valid = false;
uniform int weapon_element_kind = 1; // 1: frost, 2: electrical charge
uniform int weapon_element_variant = 0; // 0: established study, 1: alternate mechanism
uniform float weapon_element_seconds = 0.0;
uniform float weapon_element_strength : hint_range(0.0, 1.0) = 0.72;
// Exact frame-local normalized hilt XY -> tip ZW, from authored pose metadata.
uniform vec4 weapon_element_hilt_tip = vec4(0.0);
uniform float weapon_element_half_width_uv = 0.025;
uniform float weapon_element_grip_end : hint_range(0.0, 0.8) = 0.20;
uniform sampler2D weapon_element_noise : filter_linear, repeat_enable;
uniform sampler2D weapon_element_arc_sheet : filter_linear, repeat_disable;
uniform sampler2D weapon_element_ice_cells : filter_linear, repeat_enable;
uniform sampler2D weapon_element_ice_detail : filter_linear, repeat_enable;
uniform vec3 weapon_element_cold_dark : source_color = vec3(0.075, 0.16, 0.23);
uniform vec3 weapon_element_cold_body : source_color = vec3(0.25, 0.56, 0.68);
uniform vec3 weapon_element_cold_edge : source_color = vec3(0.62, 0.86, 0.90);
uniform vec3 weapon_element_electric_body : source_color = vec3(0.025, 0.13, 0.29);
uniform vec3 weapon_element_electric_halo : source_color = vec3(0.025, 0.35, 0.88);
uniform vec3 weapon_element_electric_core : source_color = vec3(0.27, 0.76, 0.97);
uniform vec3 weapon_element_electric_warm : source_color = vec3(0.92, 0.64, 0.12);

vec2 weapon_element_coordinates(vec2 cell_uv) {
    vec2 axis = weapon_element_hilt_tip.zw - weapon_element_hilt_tip.xy;
    float axis_length = max(length(axis), 0.00001);
    vec2 direction = axis / axis_length;
    vec2 offset = cell_uv - weapon_element_hilt_tip.xy;
    float across = dot(offset, vec2(-direction.y, direction.x));
    return vec2(across / max(weapon_element_half_width_uv, 0.00001),
        dot(offset, direction) / axis_length);
}

float weapon_element_blade_gate(vec2 blade_uv) {
    // Hilt exclusion is an explicit anatomical coordinate, never a normal/PCA
    // average. The real source alpha clips all missing/occluded source areas.
    return smoothstep(weapon_element_grip_end - 0.025,
        weapon_element_grip_end + 0.045, blade_uv.y);
}

float weapon_element_overlay(float base, float blend) {
    // Binbun StatusFX's overlay function, scalar form.
    return mix(2.0 * base * blend,
        1.0 - 2.0 * (1.0 - base) * (1.0 - blend), step(0.5, base));
}

vec3 weapon_element_frost(vec3 original, vec2 blade_uv, vec3 normal) {
    // Binbun IceVFX ice_shard_01_core: two actual Manhattan-cell masks.
    // The crystal lattice is deliberately fixed on the blade. Only a restrained
    // grazing highlight changes with the clock; the frozen sword never flows.
    vec2 crystal_uv = vec2(blade_uv.x * 0.24, blade_uv.y * 1.8);
    float cells = texture(weapon_element_ice_cells, crystal_uv).r;
    float detail = texture(weapon_element_ice_detail,
        crystal_uv * vec2(1.4, 1.3) + vec2(0.37, 0.16)).r;
    float joined = weapon_element_overlay(cells, detail);
    float facets = smoothstep(0.22, 0.76, joined);
    // FrostedGlass fast's normal-facing coat/rim, without screen refraction or
    // blur. A source-sheet normal is optional; the caller owns its exact frame.
    float facing = clamp(abs(normal.z), 0.0, 1.0);
    float rim = pow(1.0 - facing, 2.5);
    float glint_position = fract(weapon_element_seconds * 0.12);
    float glint = 1.0 - smoothstep(0.025, 0.095,
        abs(blade_uv.y - glint_position));
    float bevel = pow(abs(normal.x) * 0.7 + abs(normal.y) * 0.3, 2.0);
    vec3 pigment = mix(weapon_element_cold_dark,
        weapon_element_cold_body, facets);
    pigment = mix(pigment, weapon_element_cold_edge,
        clamp(rim * 0.55 + bevel * 0.35 + glint * facets * 0.16, 0.0, 0.78));
    float coat = weapon_element_blade_gate(blade_uv) * weapon_element_strength;
    return mix(original, pigment, clamp(coat, 0.0, 1.0));
}

vec3 weapon_element_clear_glaze(vec3 original, vec2 blade_uv, vec3 normal) {
    // A second ice mechanism: retain the actual steel beneath a thin glaze,
    // with fixed cellular frost veins and a normal-facing frozen bevel.
    // Unlike the opaque rime coat, its centre remains the original weapon.
    vec2 lattice_uv = vec2(blade_uv.x * 0.18, blade_uv.y * 1.9);
    float cells = texture(weapon_element_ice_cells, lattice_uv).r;
    float detail = texture(weapon_element_ice_detail,
        lattice_uv * vec2(1.7, 1.4) + vec2(0.23, 0.48)).r;
    float vein = 1.0 - smoothstep(0.018, 0.085, abs(cells - 0.50));
    float second_vein = (1.0 - smoothstep(0.015, 0.065,
        abs(detail - 0.53))) * smoothstep(0.28, 0.68, cells);
    float cracks = clamp(max(vein, second_vein * 0.65), 0.0, 1.0);
    float facing = clamp(abs(normal.z), 0.0, 1.0);
    float frozen_edge = pow(1.0 - facing, 1.8);
    float lateral_bevel = clamp(abs(normal.x) * 0.7 + abs(normal.y) * 0.3, 0.0, 1.0);
    vec3 glaze = mix(original, weapon_element_cold_body, 0.16 + cells * 0.10);
    glaze = mix(glaze, weapon_element_cold_edge,
        clamp(cracks * 0.50 + frozen_edge * 0.42 + lateral_bevel * 0.18, 0.0, 0.82));
    return mix(original, glaze,
        weapon_element_blade_gate(blade_uv) * weapon_element_strength);
}

float weapon_element_arc(vec2 blade_uv, float phase) {
    // LeLu Weapon Effects uses a 2x2 native lightning sprite sheet. Its four
    // branching shapes stay intact. Blend consecutive cells, rather than
    // drawing CPU line segments or blinking the whole material on/off.
    float frame_clock = weapon_element_seconds * 2.5 + phase;
    float selected = floor(frame_clock);
    float weight = smoothstep(0.20, 0.80, fract(frame_clock));
    vec2 arc_uv = vec2(blade_uv.x * 0.21 + 0.5,
        clamp((blade_uv.y - weapon_element_grip_end)
            / max(1.0 - weapon_element_grip_end, 0.1), 0.001, 0.999));
    float distortion = texture(weapon_element_noise,
        vec2(blade_uv.y * 1.8, weapon_element_seconds * 0.24 + phase)).r;
    arc_uv.x = clamp(arc_uv.x + (distortion - 0.5) * 0.09, 0.002, 0.998);
    float index_a = mod(selected, 4.0);
    float index_b = mod(selected + 1.0, 4.0);
    vec2 cell_a = vec2(mod(index_a, 2.0), floor(index_a / 2.0));
    vec2 cell_b = vec2(mod(index_b, 2.0), floor(index_b / 2.0));
    vec4 first = texture(weapon_element_arc_sheet, (cell_a + arc_uv) * 0.5);
    vec4 second = texture(weapon_element_arc_sheet, (cell_b + arc_uv) * 0.5);
    // Source is RGBA, not a black-keyed carrier. Multiplying alpha also makes
    // the same function safe when used in the later exterior arc layer.
    return mix(first.r * first.a, second.r * second.a, weight);
}

float weapon_element_cross_arc(vec2 blade_uv, float phase) {
    // The SAME native branching texture now spans ACROSS the blade. Short
    // discharge windows travel along it, rather than a second colour applied
    // to the axial strand. Half a cycle separates two active windows.
    float travel = fract(weapon_element_seconds * 0.32 + phase);
    float centre = mix(weapon_element_grip_end + 0.08, 0.92, travel);
    float window = 1.0 - smoothstep(0.055, 0.20, abs(blade_uv.y - centre));
    float retire = smoothstep(0.0, 0.12, travel)
        * (1.0 - smoothstep(0.86, 1.0, travel));
    vec2 cross_uv = vec2((blade_uv.y - centre) * 18.0,
        weapon_element_grip_end + (1.0 - weapon_element_grip_end)
            * clamp(blade_uv.x * 0.26 + 0.5, 0.001, 0.999));
    return weapon_element_arc(cross_uv, phase * 2.3) * window * retire;
}

vec3 weapon_element_cross_discharge(vec3 original, vec2 blade_uv, vec3 normal) {
    float first = weapon_element_cross_arc(blade_uv, 0.0);
    float second = weapon_element_cross_arc(blade_uv, 0.5);
    float fork = pow(clamp(max(first, second * 0.88), 0.0, 1.0), 0.70);
    float halo = pow(fork, 0.72);
    float core = pow(fork, 2.0);
    float bevel = pow(1.0 - clamp(abs(normal.z), 0.0, 1.0), 1.8);
    // A sustained coloured ridge keeps sparse source frames readable while
    // the two native cross-discharge windows move elsewhere on the blade.
    // This does not fill missing source alpha or turn the whole blade white.
    float ridge = 1.0 - smoothstep(0.10, 0.95, abs(blade_uv.x));
    vec3 charge = mix(original, weapon_element_electric_halo,
        0.24 + ridge * 0.16 + bevel * 0.08);
    charge += weapon_element_electric_halo * (halo * 0.65 + bevel * 0.10);
    charge += weapon_element_electric_core * ridge * 0.07;
    charge = mix(charge, weapon_element_electric_core,
        clamp(core * 0.86, 0.0, 0.86));
    // Rare warm microcontacts retain a coloured blue body rather than white.
    float warm = smoothstep(0.86, 0.99, first) * (1.0 - second) * 0.10;
    charge = mix(charge, weapon_element_electric_warm, warm);
    return mix(original, charge,
        weapon_element_blade_gate(blade_uv) * weapon_element_strength);
}

vec3 weapon_element_electric(vec3 original, vec2 blade_uv, vec3 normal) {
    // LeLu s_magic_aura3x: scrolling, noise-distorted band travelling along
    // the blade; Boringdev lightning_bolt: separate halo/core shaping. The
    // latter's repeated vec3(1) boosts are omitted to retain a blue palette.
    float arc = weapon_element_arc(blade_uv, 0.0);
    float fine = weapon_element_arc(vec2(-blade_uv.x * 1.17 + 0.32,
        blade_uv.y), 1.45) * 0.48;
    float halo = pow(clamp(max(arc, fine), 0.0, 1.0), 0.7);
    float core = pow(clamp(arc + fine, 0.0, 1.0), 2.2);
    float flow = fract(blade_uv.y - weapon_element_seconds * 0.55);
    float band = smoothstep(0.0, 0.045, flow)
        * (1.0 - smoothstep(0.12, 0.23, flow));
    float facing = pow(1.0 - clamp(abs(normal.z), 0.0, 1.0), 1.5);
    vec3 charged = mix(original, weapon_element_electric_body,
        0.34 + 0.25 * weapon_element_strength);
    charged += weapon_element_electric_halo
        * (halo * 0.52 + band * 0.10 + facing * 0.08);
    charged = mix(charged, weapon_element_electric_core,
        clamp(core * 0.82 * weapon_element_strength, 0.0, 0.92));
    float warm = smoothstep(0.75, 0.98, core) * band * 0.18;
    charged = mix(charged, weapon_element_electric_warm, warm);
    return mix(original, charged,
        weapon_element_blade_gate(blade_uv) * weapon_element_strength);
}

vec3 weapon_element_colour(vec3 original, vec2 cell_uv, vec3 current_source_normal) {
    if (!weapon_element_enabled || !weapon_element_axis_valid) return original;
    if (length(weapon_element_hilt_tip.zw - weapon_element_hilt_tip.xy) < 0.00001)
        return original;
    vec2 blade_uv = weapon_element_coordinates(cell_uv);
    if (weapon_element_kind == 1 && weapon_element_variant == 1)
        return weapon_element_clear_glaze(original, blade_uv, current_source_normal);
    if (weapon_element_kind == 1)
        return weapon_element_frost(original, blade_uv, current_source_normal);
    if (weapon_element_kind == 2 && weapon_element_variant == 1)
        return weapon_element_cross_discharge(original, blade_uv, current_source_normal);
    if (weapon_element_kind == 2)
        return weapon_element_electric(original, blade_uv, current_source_normal);
    return original;
}
#endif
