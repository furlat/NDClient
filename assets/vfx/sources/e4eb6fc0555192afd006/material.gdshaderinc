#ifndef FACTORY_WEAPON_AUXILIARY_INCLUDED
#define FACTORY_WEAPON_AUXILIARY_INCLUDED
// RGB-only equipped-item finishes. Original alpha, depth and animation remain
// on the actual source draw; explicit current-frame pose axes are mandatory.
uniform bool weapon_auxiliary_enabled = false;
uniform bool weapon_auxiliary_axis_valid = false;
uniform bool weapon_auxiliary_source_mask_only = false;
uniform int weapon_auxiliary_family = 1; // psychic, poison, radiant, necrotic, arcane
uniform int weapon_auxiliary_variant = 0;
uniform float weapon_auxiliary_seconds = 0.0;
uniform float weapon_auxiliary_strength : hint_range(0.0, 1.0) = 0.70;
uniform vec4 weapon_auxiliary_hilt_tip = vec4(0.0);
uniform float weapon_auxiliary_half_width_uv = 0.025;
uniform float weapon_auxiliary_grip_end = 0.20;
uniform sampler2D weapon_auxiliary_texture_a : filter_linear, repeat_enable;
uniform sampler2D weapon_auxiliary_texture_b : filter_linear, repeat_enable;
uniform vec3 weapon_auxiliary_dark : source_color = vec3(0.10, 0.02, 0.04);
uniform vec3 weapon_auxiliary_body : source_color = vec3(0.60, 0.10, 0.17);
uniform vec3 weapon_auxiliary_edge : source_color = vec3(0.90, 0.27, 0.22);

vec2 weapon_auxiliary_coordinates(vec2 uv) {
    vec2 axis = weapon_auxiliary_hilt_tip.zw - weapon_auxiliary_hilt_tip.xy;
    float length_uv = max(length(axis), 0.00001);
    vec2 direction = axis / length_uv;
    vec2 offset = uv - weapon_auxiliary_hilt_tip.xy;
    return vec2(dot(offset, vec2(-direction.y, direction.x))
            / max(weapon_auxiliary_half_width_uv, 0.00001),
        dot(offset, direction) / length_uv);
}

float weapon_auxiliary_gate(vec2 blade_uv) {
    return smoothstep(weapon_auxiliary_grip_end - 0.02,
        weapon_auxiliary_grip_end + 0.04, blade_uv.y);
}

float weapon_auxiliary_rim(vec3 normal) {
    return pow(1.0 - clamp(abs(normal.z), 0.0, 1.0), 1.8);
}

vec3 weapon_auxiliary_psychic(vec3 original, vec2 uv, vec3 normal) {
    // LeLu Dark Sword's marble/noise distortion, constrained to actual blade
    // coordinates. The original demo's extreme purple HDR power is excluded.
    vec2 sample_uv = vec2(uv.x * 0.18, uv.y * 1.25);
    float distortion = texture(weapon_auxiliary_texture_b,
        sample_uv * 1.7 - vec2(0.0, weapon_auxiliary_seconds * 0.14)).r;
    float marble = texture(weapon_auxiliary_texture_a,
        sample_uv + vec2(distortion * 0.16, -weapon_auxiliary_seconds * 0.10)).r;
    float veins = 1.0 - smoothstep(0.018, 0.11, abs(marble - 0.53));
    float rim = weapon_auxiliary_rim(normal);
    vec3 pigment;
    if (weapon_auxiliary_variant == 1) {
        // Discrete interference slits cross the original steel. The source
        // image is not offset or duplicated, so this is not a Blur impostor.
        float slit = 1.0 - smoothstep(0.04, 0.20,
            abs(fract(uv.y * 5.0 - weapon_auxiliary_seconds * 0.30) - 0.5));
        float interference = slit * (0.42 + smoothstep(0.20, 0.70, marble) * 0.58);
        float ridge = 1.0 - smoothstep(0.10, 0.65, abs(uv.x));
        pigment = mix(original, weapon_auxiliary_dark, 0.20);
        pigment = mix(pigment, weapon_auxiliary_body,
            clamp(0.15 + interference * 0.55 + rim * 0.16, 0.0, 0.90));
        pigment += weapon_auxiliary_edge
            * (ridge * 0.14 + rim * 0.10 + interference * 0.40);
        pigment = clamp(pigment, vec3(0.0), vec3(1.0));
    } else {
        pigment = mix(weapon_auxiliary_dark, weapon_auxiliary_body,
            clamp(veins * 0.85 + rim * 0.20, 0.0, 1.0));
        pigment = mix(pigment, weapon_auxiliary_edge, veins * distortion * 0.32);
    }
    return mix(original, pigment,
        weapon_auxiliary_gate(uv) * weapon_auxiliary_strength);
}

vec3 weapon_auxiliary_poison(vec3 original, vec2 uv, vec3 normal) {
    // Binbun Poison's two actual cellular/web masks: slow viscous coverage is
    // distinct from isolated fast travelling beads, not another tint preset.
    vec2 mask_uv = vec2(uv.x * 0.24, uv.y * 2.0);
    float web = texture(weapon_auxiliary_texture_b,
        mask_uv * vec2(1.6, 1.1) + vec2(0.12, -weapon_auxiliary_seconds * 0.08)).r;
    float rim = weapon_auxiliary_rim(normal);
    vec3 pigment;
    float coverage;
    if (weapon_auxiliary_variant == 1) {
        // Sparse moving source-cell beads preserve bare steel between them.
        // A separate scroll/scale keeps this distinct from the broad film.
        float bead_cells = texture(weapon_auxiliary_texture_a,
            vec2(uv.x * 0.55, uv.y * 4.0 - weapon_auxiliary_seconds * 0.22)).r;
        float drops = smoothstep(0.59, 0.74, bead_cells * 0.82 + web * 0.18);
        float channel = 1.0 - smoothstep(0.15, 0.45,
            abs(uv.x + (web - 0.5) * 0.45));
        coverage = clamp(drops * 0.95 + channel * 0.08 + rim * 0.05, 0.0, 1.0);
        pigment = mix(weapon_auxiliary_body, weapon_auxiliary_edge,
            smoothstep(0.62, 0.88, bead_cells) * (0.65 + rim * 0.35));
    } else {
        float cells = texture(weapon_auxiliary_texture_a,
            mask_uv - vec2(0.0, weapon_auxiliary_seconds * 0.055)).r;
        float film = smoothstep(0.20, 0.65, cells * 0.65 + web * 0.35);
        coverage = 0.55 + film * 0.40;
        pigment = mix(weapon_auxiliary_dark, weapon_auxiliary_body, film);
        float wet_ridge = 1.0 - smoothstep(0.10, 0.72,
            abs(uv.x + (web - 0.5) * 0.40));
        float liquid_glint = 1.0 - smoothstep(0.04, 0.20,
            abs(fract(uv.y * 1.7 - weapon_auxiliary_seconds * 0.18) - 0.5));
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(rim * 0.32 + wet_ridge * liquid_glint * 0.58
                + pow(web, 4.0) * 0.22, 0.0, 0.78));
    }
    return mix(original, pigment, coverage
        * weapon_auxiliary_gate(uv) * weapon_auxiliary_strength);
}

vec3 weapon_auxiliary_radiant(vec3 original, vec2 uv, vec3 normal) {
    // Source-owned etched noise and a normal-facing gold coat, with no white
    // sphere, whole-body aura, point light or global brightness pulse.
    vec2 etch_uv = vec2(uv.x * 0.20, uv.y * 1.6);
    float engraving = texture(weapon_auxiliary_texture_a, etch_uv).r;
    float grain = texture(weapon_auxiliary_texture_b, etch_uv * 2.1).r;
    float rim = weapon_auxiliary_rim(normal);
    float band = 1.0 - smoothstep(0.025, 0.12,
        abs(fract(uv.y - weapon_auxiliary_seconds * 0.27) - 0.5));
    vec3 pigment;
    if (weapon_auxiliary_variant == 1) {
        // Steel-preserving travelling sun bevel: most motion is restricted to
        // the normal-defined edge, rather than replacing the whole blade gold.
        float bevel = clamp(rim * 0.65 + abs(normal.x) * 0.22, 0.0, 0.85);
        pigment = mix(original, weapon_auxiliary_body, 0.14 + bevel * 0.30);
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(band * (0.18 + bevel * 0.58) + bevel * 0.15, 0.0, 0.83));
    } else {
        float line = 1.0 - smoothstep(0.018, 0.075, abs(engraving - 0.50));
        pigment = mix(original * 0.78, weapon_auxiliary_dark, 0.22);
        pigment = mix(pigment, weapon_auxiliary_body, line * 0.78 + rim * 0.12);
        pigment = mix(pigment, weapon_auxiliary_edge, line * band * grain * 0.65);
    }
    return mix(original, pigment,
        weapon_auxiliary_gate(uv) * weapon_auxiliary_strength);
}

float weapon_auxiliary_smoke(vec2 uv) {
    // The inspected Dark Sword uses T_VFX_gas12 as a native 4x4 flipbook.
    // Crossfade two actual cells to avoid a hard per-frame flame/smoke flash.
    float frame_clock = weapon_auxiliary_seconds * 4.0;
    float first = mod(floor(frame_clock), 16.0);
    float second = mod(first + 1.0, 16.0);
    vec2 first_cell = vec2(mod(first, 4.0), floor(first / 4.0));
    vec2 second_cell = vec2(mod(second, 4.0), floor(second / 4.0));
    vec2 local_uv = clamp(vec2(uv.x * 0.30 + 0.50,
        fract(uv.y * 1.7 - weapon_auxiliary_seconds * 0.08)), vec2(0.002), vec2(0.998));
    vec4 a = texture(weapon_auxiliary_texture_b, (first_cell + local_uv) * 0.25);
    vec4 b = texture(weapon_auxiliary_texture_b, (second_cell + local_uv) * 0.25);
    return mix(a.r * a.a, b.r * b.a, smoothstep(0.15, 0.85, fract(frame_clock)));
}

vec3 weapon_auxiliary_necrotic(vec3 original, vec2 uv, vec3 normal) {
    float marble = texture(weapon_auxiliary_texture_a,
        vec2(uv.x * 0.19, uv.y * 1.3) + vec2(0.0, -weapon_auxiliary_seconds * 0.10)).r;
    float rim = weapon_auxiliary_rim(normal);
    vec3 pigment;
    if (weapon_auxiliary_variant == 1) {
        // Stable hollow channels with a moving inner charge; the underlying
        // source is neither erased nor dissolved, and no lost HP is inferred.
        float hollows = 1.0 - smoothstep(0.04, 0.22, abs(marble - 0.48));
        float inner = 1.0 - smoothstep(0.025, 0.09, abs(marble - 0.48));
        float charge = 0.55 + 0.25 * sin(uv.y * 13.0 - weapon_auxiliary_seconds * 1.8);
        pigment = mix(original * 0.80, weapon_auxiliary_dark, hollows * 0.68);
        pigment = mix(pigment, weapon_auxiliary_body, hollows * 0.25 + rim * 0.18);
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(inner * (0.32 + charge * 0.50) + rim * 0.16, 0.0, 0.86));
    } else {
        float smoke = weapon_auxiliary_smoke(uv);
        pigment = mix(weapon_auxiliary_dark, weapon_auxiliary_body,
            smoothstep(0.12, 0.78, smoke) * 0.75);
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(smoke * marble * 0.22 + rim * 0.12, 0.0, 0.42));
    }
    return mix(original, pigment,
        weapon_auxiliary_gate(uv) * weapon_auxiliary_strength);
}

vec3 weapon_auxiliary_arcane(vec3 original, vec2 uv, vec3 normal) {
    float rim = weapon_auxiliary_rim(normal);
    float detail = texture(weapon_auxiliary_texture_a,
        vec2(uv.x * 0.18, uv.y * 2.2)).r;
    vec3 pigment;
    if (weapon_auxiliary_variant == 2) {
        // Shillelagh's actual wood: long grain channels stay attached while a
        // sparse sap/glow front advances toward the tip. No replacement staff.
        float grain = texture(weapon_auxiliary_texture_b,
            vec2(uv.x * 0.8, uv.y * 0.20)).r;
        float channels = 1.0 - smoothstep(0.025, 0.13, abs(grain - 0.48));
        float growth = 1.0 - smoothstep(0.025, 0.14,
            abs(fract(uv.y - weapon_auxiliary_seconds * 0.20) - 0.5));
        pigment = mix(original, weapon_auxiliary_body, channels * 0.50);
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(channels * growth * 0.62 + rim * 0.16, 0.0, 0.80));
    } else if (weapon_auxiliary_variant == 1) {
        float sweep = 1.0 - smoothstep(0.025, 0.10,
            abs(fract(uv.y - weapon_auxiliary_seconds * 0.28) - 0.5));
        pigment = mix(original, weapon_auxiliary_body, 0.10 + rim * 0.12);
        pigment = mix(pigment, weapon_auxiliary_edge,
            clamp(sweep * (0.25 + detail * 0.35) + rim * 0.16, 0.0, 0.80));
    } else {
        float etched = 1.0 - smoothstep(0.018, 0.085, abs(detail - 0.52));
        float scan = 0.45 + 0.35 * sin(uv.y * 15.0 - weapon_auxiliary_seconds * 1.5);
        pigment = mix(original, weapon_auxiliary_dark, etched * 0.24);
        pigment = mix(pigment, weapon_auxiliary_body, etched * 0.58);
        pigment = mix(pigment, weapon_auxiliary_edge, etched * scan * 0.28 + rim * 0.10);
    }
    return mix(original, pigment,
        weapon_auxiliary_gate(uv) * weapon_auxiliary_strength);
}

vec3 weapon_auxiliary_colour(vec3 original, vec2 source_cell_uv, vec3 valid_source_normal) {
    if (!weapon_auxiliary_enabled) return original;
    if (!weapon_auxiliary_axis_valid) {
        // A surviving source mask can receive a quiet finish even when no
        // physical hilt/tip is disclosed. No directional grain, moving sheath
        // or guessed weapon geometry is manufactured in this explicit mode.
        if (!weapon_auxiliary_source_mask_only ||
            (weapon_auxiliary_family != 1 && weapon_auxiliary_family != 3
             && weapon_auxiliary_family != 4 && weapon_auxiliary_family != 5))
            return original;
        float rim = weapon_auxiliary_rim(valid_source_normal);
        vec3 finish = mix(original, weapon_auxiliary_body, 0.16);
        finish = mix(finish, weapon_auxiliary_edge, rim * 0.28);
        return mix(original, finish, weapon_auxiliary_strength);
    }
    if (length(weapon_auxiliary_hilt_tip.zw - weapon_auxiliary_hilt_tip.xy) < 0.00001)
        return original;
    vec2 blade_uv = weapon_auxiliary_coordinates(source_cell_uv);
    if (weapon_auxiliary_family == 1)
        return weapon_auxiliary_psychic(original, blade_uv, valid_source_normal);
    if (weapon_auxiliary_family == 2)
        return weapon_auxiliary_poison(original, blade_uv, valid_source_normal);
    if (weapon_auxiliary_family == 3)
        return weapon_auxiliary_radiant(original, blade_uv, valid_source_normal);
    if (weapon_auxiliary_family == 4)
        return weapon_auxiliary_necrotic(original, blade_uv, valid_source_normal);
    if (weapon_auxiliary_family == 5)
        return weapon_auxiliary_arcane(original, blade_uv, valid_source_normal);
    return original;
}
#endif
