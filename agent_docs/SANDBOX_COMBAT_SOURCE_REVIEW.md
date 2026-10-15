# Combat sandbox source review — 2026-10-14

This batch adds ten source selections to the offline spell sandbox. It changes
neither gameplay rules nor production spell JSON. The ten Resources use
`sandbox/spell.gd`, retain their existing `authoring/spells/spell.*.json`, and set
`effect_scale = 0.18` so the cue's uniform scale is used directly.

The source root is
`C:/Users/tommaso/Documents/assets/VFXFactory`. Paths below are relative to that
root. Selection and staging are in
`authoring/sandbox/batches/combat.json`. Native visual qualification belongs to
the subsequent shared importer/runtime capture; this review does not claim
rendered equivalence or final scale tuning.

## Initial complete source selections

All ten sequence cues are attached native compositions beginning at cast
release. They contain no invented flight phase. `side = full` means one complete
source, not two overlapping front/back exports. The Factory's selected scripts
and source material edits remain part of the composition.

| Spell | Factory recipe; component | Native composition | Attachment and finite source interval |
|---|---|---|---|
| Bane | `recipes/spells/bane.json`; `recipient/bane.gd` | Binbun `vfx_status_void`, original three orbit brands, six smoke wisps, tears and ground marks | Target ground, scale 0.5; 0–4 s. Original opening and closing envelope. |
| Command | `recipes/spells/command.json`; `recipient/control_status.gd` | Selected Binbun gem donor and original command glyph. The declared sleep donor is hidden by the source itself. | Target ground, scale 0.5; 0–3.5 s. Original emission stops at 2.25 s; explicit sandbox-only 0.35 s closing fade. |
| Mage Armor | `recipes/spells/mage_armor.json`; `recipient/protection.gd` | LeLu `VFX_Shield_blue_wild`, native sphere, alternating particle cohorts and material clock | Target ground, scale 0.5; 0–7.2 s. Real `end_animation` at 5 s, emission stop at 5 s, two-second particle tail retained. |
| Sanctuary | `recipes/spells/sanctuary.json`; `recipient/protection.gd` | LeLu `VFX_YinYang_beam`, selected native rings/sparks plus the source's overhead SanctuaryMark | Target ground, scale 0.5; 0–6 s. Source fades at 4.8–5.6 s. |
| Shield | `recipes/spells/shield.json`; `recipient/protection.gd` | LeLu `VFX_Shield_hex`, full native opening, sphere and closing | Caster ground, scale 0.5; 0–3.7 s. Real `end_animation` at 3 s lasts 0.6 s. |
| False Life | `recipes/spells/false_life.json`; `recipient/blessing.gd` | Binbun status-green composition with the Factory's original teal palette and envelope | Caster ground, scale 0.5; 0–4 s. Original closing envelope. |
| Sacred Flame | `recipes/spells/sacred_flame.json`; `recipient/sacred_beam.gd` | LeLu `VFX_Vertical_Hell_beam_blue`, source's holy recolor, descending beam and ground flare | Target ground, scale 0.5; full 0–5 s native Init. Contact at source tick 52/144. |
| Shocking Grasp | `recipes/spells/shocking_grasp.json`; `recipient/cantrip_donor.gd` | LeLu `VFX_Sparks_Bk1`, source's electric sparks and native material/particle edits | Target body, scale 0.5; 0–1.5 s. Emission to 1.25 s plus original 0.25 s particle lifetime. |
| Burning Hands | `recipes/spells/burning_hands_production_xyz.json`; `recipient/approved_aoe_whole.gd` | LeLu `VFX_Flamethrower_Anime_B`, all three registered FlameComponents meshes and 320 original source particles | Caster hand registered to `effect/Donor/fire`, scale 0.5; 0–1.5 s. Native End at tick 80/144 and complete 0.65 s particle tail. |
| Thunderwave | `recipes/spells/thunderwave_production_xyz.json`; `recipient/approved_aoe_whole.gd` | Original ThunderCrest blend-shape mesh, pressure echo and dust from the selected production variant | Caster ground, scale 0.5; 0–1 s, including native collapse through 0.89 s. |

The resolved lifecycle IDs are `spells/<recipe-name>/back/lifecycle`, except the
two production AoEs, whose variant is `whole`. Three additional native phases
are available for inspection: `spells/bane/back/sustain`,
`spells/false_life/back/sustain`, and `spells/shield/back/hit_E`. They are optional
and are not additional sequence instances. Shield casting does not fabricate an
incoming hit to trigger its optional response.

## Placement, contact and lifetime choices

- Recipient status sources preserve a world-upright composition. The caster is
  at `(-2,0,0)` in this sandbox. Mage Armor and Shocking Grasp place the recipient
  at `(-1,0,0)` for the touch/close demonstration. The two AoEs place it at
  `(0,0,0)`, two cells from the caster and inside their selected footprint.
- Burning Hands and Thunderwave source scripts already orient their native
  forward direction to +X. A 90-degree Y rotation converts +X to the shared
  facing convention's -Z. The outer transform applies yaw only; it does not tilt
  an entire ground effect toward a raised body socket. Source cells are two
  units wide, so uniform scale 0.5 maps them to one world cell. This is the initial
  geometric calibration, pending visual review.
- Burning Hands contact is 0.28 s: the existing two-cell travel at
  `contact.speedTilesPerSecond = 8` plus `contact.delayMs = 30`. Thunderwave uses
  the existing E far-cell contact `60/144` s. These are authored preview contact
  clocks, not collision tests inferred from rendered brightness. Sacred Flame
  retains its source's exact ground-flare tick 52.
- Bane/False Life already call native close and reduce their source envelope.
  Mage Armor/Shield explicitly invoke their actual
  `effect/Donor/AnimationPlayer:end_animation`. The source otherwise only
  auto-invokes ending for Shield, and Shield's recipe sets that tick effectively
  infinite. The finite preview close is recorded here rather than presented as
  a gameplay expiration.
- Command has no closing animation for its persistent glyph. Its selected
  particle emission stops at 2.25 s, with a 0.85 s tail. The explicit final 0.35 s
  preview transparency fade closes that glyph before its source's four-second
  restart. This is the only added whole-composition fade in this batch.
- Sanctuary's own geometry and material fade is complete at 5.6 s. Its
  `duration_policy = authored` prevents a longer, now-invisible donor Init from
  extending the six-second preview. Sacred Flame instead retains the entire
  five-second Init rather than the exported 3.5-second capture window.
- Only Sacred Flame, Shocking Grasp, Burning Hands and Thunderwave have existing
  damage authoring. Their existing hit flash, number and death options remain.
  No damage reaction is added to the six protection/status spells.

## Required shared source adaptations and dependencies

These were reported to the integration owner; this data lane did not edit the
Factory sources or shared runtime.

1. Resolve phase `component_overrides` before constructing components. Bane and
   False Life sustain inputs differ from lifecycle; Shield hit phases use their
   own input/scene. Losing these overrides would select the wrong native source.
2. For `side = full`, remove only the source export half-plane predicate in
   `blessing.gd`, `protection.gd`, `control_status.gd` and the shared base path.
   In `sacred_beam.gd`, retain `split_world` and the separate descending Y cutoff.
   `cantrip_donor.gd` already guards full composition. The selected
   `approved_aoe_whole.gd` already removes the AoE tile and half-plane guard; do
   not replace it with one clipped cell or nine copies.
3. Sanctuary's base input lacks `mark_direction`; its Factory view supplies it.
   The batch supplies exact q0 `[12,9.797958971,12]` and a shared view binding to
   `effect/Donor/SanctuaryMark`. `protection.gd` reads the direction both during
   construction and while sampling its original wobble. Camera updates must
   preserve that wobble and work while paused.
4. Command's source creates a camera-readable overhead glyph but only calls
   `look_at(... + Vector3(12,9.797958971,12), UP, true)` at construction. Its shader
   has no billboard vertex path. Four-view capture must check that glyph; any
   adaptation should retain its original forward-facing plane, not reuse
   Sanctuary's UP-plane orientation blindly.
5. Burning Hands loads an explicit external native geometry registry:
   `recipes/data/selected_23_completion_20261009/additional_xyz/flame-geometry.json`.
   Its Linux file is
   `/home/tommaso/.codex/worktrees/1aac/dnd_engine/output/weapon-vfx/godot-library/projects/lelu-godot-fire-premium/codexfx_exporter/FlameComponents.glb`;
   Windows uses the corresponding `//wsl.localhost/Ubuntu-24.04/...` path. The
   file exists on the current host. `readonly_geometry.gd` verifies its existing
   registry digest and requires exactly three meshes. The importer's `res://`
   closure alone does not copy this external file. A missing registry target is
   a real dependency failure; no generic flame mesh is an acceptable fallback.
6. Thunderwave directly depends on
   `factory/resources/aoe_crest/codexfx_exporter/ThunderCrest.glb` and its shader;
   these are ordinary selected `res://` dependencies.
7. Preserve source settings and palettes. Mage Armor, Shield and Sanctuary
   additionally describe a Factory `glass_palette_v1` finishing profile using
   `palette_pass.palette`, whereas the current sandbox finishing seam reads
   `ramp`. Retaining native donor/material colors is distinct from reproducing
   that finishing profile; translation and native qualification belong to the
   integration pass. No new arbitrary tint or replacement source is specified
   here.

## Validation status

The bounded source/data check passed **213 checks, zero failures**: exact ten-spell
scope, thirteen resolvable phases, selected component scripts/scenes/input
dependencies, actual end-animation/player names, finite cue intervals and
attachments, phase-specific sustain inputs, ten Resource references, and the
existing four-versus-six damaging/non-damaging authoring distinction. The check
imports only the Python resolver and reads data; it does not run the importer.

No Godot process, native capture, asset copy, source modification or new effect
was launched by this lane. Required next evidence is the shared native pass:
whole composition and source palette, open/close including particle tails,
four-view overhead marks, actual contact placement, and no-damage behavior for
protection/status spells. Native capture/tuning must update that evidence rather
than treating these data checks as rendered proof.

## Native integration follow-up

Root completed the combined 20-spell four-view native suite (1510 checks), all 31
isolated phases, and retained the original 14-spell regressions (1368 checks).
Sacred Flame's later full-beam framing passed 90 further checks. All source-review
blockers raised for this batch were corrected; see sandbox/README.md and the
`.runtime/sandbox-batch-all 20-checks.json`/framing reports for precise evidence.
The finite holds are offline presentation fixtures, not invented gameplay duration.

## False Life body-surface follow-up — 2026-10-15

The initial external sustain cage above is superseded. False Life keeps its
native application, then crossfades into a film on the assembled body and gear.
The selected sustain still owns the material and clock: `effect/Donor/Mesh`
provides the original status-green noise texture, recoloured primary/secondary/
tertiary colours, noise scale, scroll, twist, waviness, emission and sampled
`support_clock`/`support_envelope`. The source mesh is hidden during this phase;
the adapter creates no replacement geometry, light or timer.

The film samples that noise with normal-weighted triplanar projection at the
existing reconstructed body surface, relative to the actor origin. It requires
valid delivered depth, support and normal data. Original painted body/gear alpha
is retained; pixels without those valid data receive no film. This is an explicit
surface adaptation, not a claim that the donor sphere shader transfers unchanged:
body alpha replaces the sphere UV edge mask, downward-facing normals select its
tertiary colour, and a common scalar limits the emissive RGB peak while preserving
hue. Transient hit colour retains priority over the persistent film.

The authored scale is 1.5. Nominal strength 1.0 combines once with the native
0.595 envelope and authored 0.25 hold opacity, giving a maximum blend strength of
0.14875 before the source noise coverage. Application lasts two seconds; the
four-second sustain starts at 1.5 seconds, preserving the crossfade. These remain
finite sandbox preview intervals, not server condition durations. The same
selection works in the isolated sustain preview.

Windows Godot 4.7.2 Forward+ Vulkan qualification passed **262 checks, zero
failures**, with no engine warnings/errors. It covers four camera quarters, two
different actual Idle frames per quarter, isolated sustain, native application,
source-clock/envelope sampling, unchanged alpha/coverage, functional depth and
normal controls, exact paused restoration, expiry, recast, explicit removal of
all surface bindings, and a switch to Shield. Each qualified film sample changed
1,480–2,109 painted body pixels and **zero pixels outside the recipient's painted
coverage**. The empty-binding check exposed a real cached-output reset defect;
the final run verifies resets on both source and retained output materials.

Evidence: `.runtime/sandbox-body-surface-checks.json`,
`.runtime/body-surface-native-2.log`, and `.captures/body-surface/` (application,
film/off pairs and isolated views). The earlier failed control report remains at
`.runtime/sandbox-body-surface-first-control.json`. Captures were inspected: the
teal pattern follows body/gear surfaces, with no external cage or floor spill.
This qualifies the implemented surface behavior; final artistic preference is
still a user decision.

The subsequent shared compositor/Bless regression passed **830 checks, zero
failures**, with a clean native exit. Both original source materials retain their
own noise, palette and animated clock when applied together; neither silently
replaces the other. Removing either layer restores the exact remaining layer,
and removing both restores the original body. The combined film changes zero
pixels outside painted recipient coverage. Full-strength transient body colour
still renders above persistent films, verified with an explicit shader-order
control rather than a fabricated damage event.

Composition uses one shared geometry reconstruction and native shader arrays,
with stable priority/ID order. Eight simultaneous surface layers is an explicit
renderer capacity, not a limit on game conditions; excess layers produce named
missing diagnostics. Selection of canonical conditions remains with the existing
owner. The test exercises deterministic overflow, live source animation, actual
sandbox looping and source removal. All sixteen pre/post-compositor False Life
film/off scene images match exactly; twelve full-window images differ only in
the phase/FPS label refreshed by the newly exercised loop path.

Latest evidence is `.runtime/sandbox-body-surface-bless-stacking-830.json`,
`.runtime/body-surface-stacking-native.log` and
`.runtime/body-surface-single-layer-parity.json`. New captures use
`false_life-q*`, `bless-q*` and `stack-*` names in `.captures/body-surface/`.
Bless's native burst remains visible during application and crossfades into its
body film; its separate source review owns that spell's authored intervals.
