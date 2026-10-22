# Factory handoff: prepared receiver for supplied dragon normal policy

**DELIVERED — 22 October.** Complete sealed
`runtime-dragon-receiver-20261022-53075ee7ed11481f` supplies both exact aliases
requested below, preserving old programs/defaults. The Factory namespace gate
passes127 functional checks; its static exit diagnostics and runtime costs remain
explicit. [Actual delivery](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/docs/DRAGON_RECEIVER_PROGRAM_DELIVERY_2026-10-22.md).
Client offline extraction is complete; adoption/source integration is next.
This is no longer an outstanding Factory request. The original request below
preserves its historical source boundary; client pixels/art remain unqualified.

22 October 2026 — prospective client source compatibility, under the existing
creature intake and R2/R3 renderer scope.

**Source-reviewed request; client shader candidate remains unapplied pending
the matching prepared program.** The installed renderer is unchanged. This is
not an existing package defect or a request to repeat §17's b61 aperture fix,
which is delivered and installed. It is the offline program preparation needed
for the supplied dragon's independent normal/depth masks.

The selected 21 October dragon packet already supplies Sprite Fusion Default
normals and independent normal-admission/depth/caster masks. The current
client's normal-receiving predicate intersects depth and support. The reviewed
four-file candidate introduces two explicit per-source receiving operands,
without changing native 3D geometry, body-surface geometry, caster admission,
source pixels or any lighting equation.

## Exact source to prepare

Read the exact proposed source closure at:

`/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/dragon-independent-normals/source-files/NDClientGodot/`

The root is `modular.gdshader`. The [source manifest](../.runtime/closing-repairs/dragon-independent-normals/receiving-source.json)
lists every dependency and the [literal expanded source](../.runtime/closing-repairs/dragon-independent-normals/expanded-source.gdshader).
The [complete portable source bundle](../.runtime/closing-repairs/dragon-independent-normals/factory-source-handoff.zip)
contains all nine source files, manifest, expanded witness, client patch and this handoff.

| Identity | Exact value |
| --- | --- |
| Previously installed raw root | `b61cce83cd020141731a4cd4385ef3b52e6d9da0a13ca80b0f8ef25e9e746a1f` |
| Previously installed expanded source | `aa44590e5ca4ed65917b5b06e81b8ab596bda7d1b3affcd29f0d875eb071b9bf` |
| Proposed raw root | `21beb4c253aca18c34938713c7648ef29b279c0b88edf92e46ee5966e23ed07c` |
| Proposed literal expanded source | `8d1e8295804c17220d7ef263603ecae93b6acd2e9dc23198c3c4ec199fe37490` |

The eight includes are unchanged: source_colour_modular, character_material,
native_body_material, native_spell_finish, body_surface, lit_receiving,
light_table and native_scene_vertex. The witness expansion of the previous
closure matches the installed expanded source byte-for-byte. These keys are
source identities, not the hash of a prepared weapon-receiver output shader.

New actual uniforms:

```glsl
uniform bool component_normal_requires_depth = true;
uniform float component_normal_alpha_threshold = 0.5;
```

Only the first lighting-normal predicate changes:

```glsl
bool valid = texture(component_normal_valid, source_uv).r > 0.5
    && normal.a > component_normal_alpha_threshold
    && (!component_normal_requires_depth
        || (texture(component_support, source_uv).r > 0.5 && depth.a > 0.5));
```

Defaults reproduce the existing coupled mask/depth/normal-alpha predicate.
Later selected Sprite Fusion data would explicitly use `false` and `7.0/255.0`.
Keep the depth-dependent `native_scene_receiver`, geometric `body_surface`
branch and shadow caster unchanged; no receiving normal fabricates depth.

## Existing preparation deliverable

Prepare the existing equipped receiver through the same offline workflow used for the b61 aperture
correction. Preserve all old bank entries. Add matching raw/expanded-source
aliases, `programs`, complete `uniforms`, `default_textures` and source-revision
provenance for this exact new source closure. Include both added uniform names
and their real defaults, plus the unchanged `component_reconstruction_origin`
uniform used by the separate per-facing data projection.

Preserve actual source colour, opacity, alpha, masks, normal/depth bindings,
frame UV, aperture lip/shadow exclusion, native-body/material composition,
receiving equations, equipped material ownership, private clocks and public
constructor/pose contracts. Do not alias the new keys to the old shader: its
expanded root still contains the old predicate and no new policy uniforms.
Do not mutate the currently installed sealed bank or generate source code at
runtime. Supply the normal existing complete candidate/package handoff.

The installed adapter's exact-hash lookup is
`assets/vfx/sources/b030caea4fa2359738f0/equipped_treatment.gd::_hook`.
Its existing missing-program refusal is intentional. No new Factory API,
backend fact, art, mask or event clock is requested. Pixel/old-default/native
compatibility remains a later coherent qualification after client adoption of
both source and matching bank. All artwork remains UNREVIEWED.
