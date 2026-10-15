# Selected native effects

These records select actual source counterparts, not new artwork. `media_ids`
links the existing full authored media identity; Magic Missile additionally has
an explicit `phase`. The source plan is
`agent_docs/GODOT_STUDIO_BASE_MECHANICS_PLAN_2026-10-13.md`.

The `spells` table selects the shared-World3D path for the30 non-deferred
capabilities in the current sandbox batch. **Aid, Bless, False Life and Sacred
Flame remain deferred and are not activated here.** Registration is technical
availability, not artistic approval; timing and placement still need tuning for
every spell. See the
[migration plan](../../agent_docs/NATIVE_SPELL_CLIENT_MIGRATION_PLAN_2026-10-15.md)
and [Factory handoff](../../agent_docs/NATIVE_VFX_FACTORY_HANDOFF.md) for current
qualification.

`presentation/native_spell_authoring.gd` reads the existing imported manifest,
flat projectile staging and nested `sandbox/batches/{combat,support}.json`
staging. Manifest clips already contain their selected source/material overrides.
The production selection omits sandbox delivery counts, target fixtures, test
body actions and local hold durations. Entry `delivery` describes real application
versus area ownership; Ice Knife's separately recorded burst has its own role
selection. Shield's demonstration hostile projectile is excluded; its native
contact source is available only to actual interception events.

Entry `lifecycle` names exact disclosed condition or spatial-effect owners,
source cue IDs, replaced legacy media and source-time windows. The currently
finite donor lifecycles use an explicitly held native pose between opening and
closing. That held source pose is a rendering choice, not a game-duration rule
or an assertion of a seamless animated sustain. Actual owner removal/suppression
controls visibility and closure. Existing markers and recipient restraint layers
remain separate. Light's native orb does not add another optical emitter over
the authoritative light state. Web's native ground mesh is clipped to the actual
disclosed, unsuppressed cells.

`source_bounds` stores measured native animation lengths, particle tails and
source-light property tracks. Per-emitter paths let release/contact controls
exclude hidden subtrees while retaining visible smoke and ribbons. GPUTrail's
`length_seconds` defines its decay; its `lifetime` is a history-sample count,
not a duration. Regenerate this metadata with Windows Godot:

```text
--headless --path <client> --script res://tools/native_spell_light_intake.gd -- --write-index
```

This finite intake samples source components/AnimationPlayers for light metadata;
it does not run geometry trail callbacks or qualify framebuffer output. Reports
stay under `.runtime/native-spell-light-{intake,inventory}.json`. The actual light
animation remains source-owned. No new artwork is imported by this command.

The interfaces and historical Magic Missile adapter below describe the older
`sources` path, which still serves the class and blood selections.

Regenerate the selected dependency closure (originals are never written):

```sh
python3 tools/prepare_native_effects.py \
  --factory /mnt/c/Users/tommaso/Documents/assets/VFXFactory \
  --class-source /home/tommaso/Dev/neurodragon_art/sources/class-actions-roar-cast-v5-20261004 \
  --class-selection /mnt/c/Users/tommaso/Documents/Dev/dnd_engine/game_obsolete/data/class_media/source.json
```

Adopted files live in Gitignored `assets/native_effects/`; the intake receipt is
`.runtime/native-effect-intake.json`. The class adapter preserves the six
Action Surge ribbons and nineteen motes. It renders the original rear/front
halfplanes with two cameras on **one** simulation; each original half gets the
original whole-composition palette operator. Rage mantle/ground and Second Wind
select the same source code with their actual original palettes and durations.

The adopted changes are path rebasing; explicit source clocks for the two blood
liquid shaders; original class halfplane selection per capture camera; and the
mote material's equivalent original colour and whole-mote centre selection.
Factory Magic Missile keeps its selected donor scene, material substitutions,
seed/emitter settings, and complete CIE palette. Donor lights are disabled.

## Shared caller interface

- `NativeEffects.prepare(source_ids, cache)` starts/polls existing ResourceLoader
  jobs for the finite current/upcoming component set. `make`/`configure` creates
  native nodes on the main owner. Prewarm private instances before admission to
  avoid first-use scene/shader work at the visible boundary; loading alone does
  not promise the first GPU program is already compiled.
- `NativePreview.configure(source_id, cache, occurrence_seed)` creates the source.
- `sample(age_seconds, camera_basis, world_position, scale, history, receiving)`
  uses the caller's display clock. There is no helper timer.
- `draw_entries(id, placement, back_layer, front_layer)` exposes the original
  painter halves. The host owns ordering/lifetime; `texture()` exposes a bounded
  thumbnail of those same captures, without duplicate simulation.
- `close()` releases only that occurrence's source, materials, views and outputs.

Particle history is an immutable array of `{age_seconds, transform}` rows,
including the exact terminal partial age. Transforms are source-local relative
to one stable output anchor, not raw actor-world transforms. The current native
transform may be supplied separately as `native_transform` for exact curve
sampling. `native_frame_seconds` is the real, unscaled render delta;
`native_continuous` follows whether the shared presentation clock is advancing.
The source keeps its original native `fixed_fps`; speed is derived from the
requested age delta. Backward/different-history sampling resets that same seeded
simulation and replays the bounded declared history one draw at a time. A paused
prepared age does no extra simulation. No helper timer or frozen export cadence
is introduced. Capture framing includes the known path without lowering source
pixel density. Moving Magic Missile's independent native-frame parity is still
under validation; source loading alone is not qualification.

## Measured weapon trail

`class.martial.slash` reuses the original Strike smear geometry and shader. Its
caller provides the selected facing's `weapon_path` (nullable measured points),
`weapon_path_fps`, `weapon_contact_seconds`, and `weapon_scale_x`. Native source
age is the caller's elapsed clip time retimed by `.67/contact_seconds`; the path
sample is `native_age*contact_seconds/.67*clip_fps`. Missing points omit the whole
smear, matching the recovered authored-pose renderer. There is no fixed15-frame
or12FPS assumption. `class.martial.impact` retains the original textured plane
and eighteen animated shards.

## Receiving qualification

Blood keeps its original shader/animation/COLOR/dissolve data. Its native source
colour, normals and material fields can feed the existing native Canvas lights
through `bind_receiving(source_lighting)`. Caller context contains the actual
`screen_origin`, `pixel_scale`, scalar `light_cap`, source orientation
`source_basis`, and explicit supporting source-local unit-plane `Transform3D`s.
The selected ground source is the original `Decal_Blood_Animated_A1` PlaneMesh,
with original dissolve, normal and roughness animation. Its existing centre is
registered on the supplied support. J1 remains an unselected wall projector; it
is not repurposed as a floor decal. Ground output is clipped against the explicit
support depth. No donor world environment or lights are used.
The current isolated four-view source/receiving run passes 124 checks. The actor
partition fixture passes 84 checks: one simulation is split before alpha blending
at the target’s declared upright presentation plane. Full-side RGBA and the
coverage union remain exact. Optical normal/depth packets are never sorting
authority. `bind_actor_partition(current_foot, camera_basis, fixed_anchor, scale)`
updates that plane without moving or resimulating the cloud. The recorded OA
fixture passes 42 checks using the final retained-facing impact receipt: the
current target painter key follows resumed movement while the cloud anchor stays
fixed across all four views. Elevated support and scenery crossings remain
separate integration acceptance. Composition normals and
Canvas shininess are explicitly a 2D receiving adaptation, not an assertion of
identical donor 3D microfacet lighting or arbitrary sprite-surface decals.

## Finite evidence

Run Godot `tests/native_effect_render_checks.gd`, then
`uv run --with pillow --with numpy python tools/check_native_effect_pixels.py`.
The original source reference is prepared by the intake tool. The current 24
four-quarter/three-age/half captures match original raw RGBA and the independent
original CPU pack/palette operator exactly (48 checks). This does not replace
production actor occlusion acceptance.

`tests/native_effect_source_checks.gd` passes 63 headless source/ownership checks,
including isolated mutable nested ground gradients and original martial impact
motion. `tests/native_effect_receiving_checks.gd` covers all four views of the
actual A1/A2 spray and selected ground deposit, including receiving light
response, source alpha/normal invariance, support requirements and completed-draw
readiness. Source/receiving coverage is distinct from full Studio host teardown.
The continuously advancing particle and moving-Missile fixtures are being rerun
against native playback after replacing the earlier request-time sampler; older
304-check evidence belongs to that earlier sampler and is not current proof.


## Passive migration inventory and remaining gaps

Regenerate the current authored-reference inventory without importing assets:

```sh
python3 tools/audit_native_migration.py \
  --factory /mnt/c/Users/tommaso/Documents/assets/VFXFactory \
  --class-source /home/tommaso/Dev/neurodragon_art/sources/class-actions-roar-cast-v5-20261004 \
  --class-records /mnt/c/Users/tommaso/Documents/Dev/dnd_engine/game_obsolete/data/class_media
```

`generated/native_migration_inventory.json` contains exact authored JSON pointers,
registration state, selected native records and preserved source provenance. It
currently covers 1,257 distinct media identities across 2,334 exact references in
191 authoring files: 1,675 authored assignments and 659 registration references.
9 identities map to the 12 imported native source records, 37 have preserved
class-native capture provenance but no selected adapter record, 325 have only
unqualified Factory family candidates, 80 are authored static-image identities,
8 are original particle-data identities, and 798 have no exact native counterpart
in the inspected mappings. These migration categories describe present references;
they do not establish missing artwork or rendered qualification. Absent JSON
assignments are a separate authoring audit. All selected native preload paths
exist. Unregistered/standalone sheet metadata is reported separately.

- Frenzy, Relentless, Indomitable and other class selections retain their exact
  original conversion/capture metadata. Their palettes, timing and selection
  still need an explicit native record and production qualification; sharing a
  source family is not enough to mark that complete.
- Hold Person and other spell/condition families have Factory candidates, often
  including rejected revisions. The report preserves these as candidates, never
  substitutes a similar scene or assumes the candidate list proves identity.
- Magic Missile source intake and advancing trajectory/age checks exist, but the
  independent native-control image comparison still has two failures. It is not
  qualified as exact native playback parity. There are no further imports in
  this inventory pass.
- Blood actor-plane ownership/registration is qualified narrowly. Its selected
  bright elongated spray is preserved; this does not assert visual approval or
  correct compositing across arbitrary scenery. Ground support remains explicit.

Use `generated/condition_coverage_catalog.json` from `tools/condition_coverage.gd` for the
separate 160-condition mechanism requirements, missing adapters and actual
recording/render evidence. Native source availability must not turn those
requirements green. The Factory source audit also distinguishes missing original
dependencies from optional demo/import cache paths; this inventory does not
reinterpret its static audit as a native runtime pass.
