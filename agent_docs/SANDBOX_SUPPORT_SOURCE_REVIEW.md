# Native support-spell source review

Reviewed 14 October 2026. This is the source intake for Aid, Bless, Cure Wounds,
Healing Word, Guidance, Resistance, Light, Thaumaturgy, Shield of Faith and
True Strike in the **offline sandbox**. It does not author authoritative healing outcomes,
conditions, targeting rules, attack results or server events. The explicitly
authored True Strike follow-up below is an offline visual demonstration.

The editable selections are in
[`authoring/sandbox/batches/support.json`](../authoring/sandbox/batches/support.json).
The ten ordinary `sandbox/spell.gd` Resources provide identity and the existing
client spell JSON. There is one attached native lifecycle in each Sequence.
Eight additional phases remain individually selectable: Bless sustain and seven
Factory `production_impact` selections. Those selections do not create duplicate
simultaneous applications. Each selected phase has explicit `clip.placement` with
its attachment, scale, orientation, source rate/end and any close controls; phase
isolation must not fall back to the caster's launch marker or a different scale.
Bless sustain retains the source's exact 289/144 s cycle (2.0069444444444446 s),
rather than inheriting the 5.1 s lifecycle ending. A production selection is an
export frame selection of the same source composition, so the native inspector
keeps its complete lifecycle.

## Timing and placement

Each cue starts at release, with `contact_after_release=0`, source rate 1 and no
invented projectile. Ground attachments preserve the Factory's authored internal
height. The table's **root scale** is an explicit, provisional conversion from
source units into the sandbox's world units, applied once in addition to the
Factory's internal scale. The Resource `effect_scale=0.18` leaves that authored
staging scale at its default. These numbers are source-reviewed, not yet visual
approval; actual four-view captures own the final scale and appearance judgment.

| Spell | Attachment and recipient | Root scale | Source end | Source lifecycle evidence |
|---|---|---:|---:|---|
| Aid | Target ground | 0.60 | 7.1 s | Factory close at `720/144=5 s`; native close stops emission 0.1 s later; longest particle lifetime 2 s. |
| Bless | Target ground | 0.55 | 5.1 s | Factory close at `432/144=3 s`; native stop at +0.1 s; particle lifetime 2 s. Sustain is separately selectable. |
| Cure Wounds | Target torso | 0.30 | 3 s | Native `Init` lasts 3 s. Small particles start at 0.133333 s with lifetime 2 s; curated puff starts at 0.25 s with lifetime 0.85 s. |
| Healing Word | Target torso | 0.35 | 3.16667 s | Native `Init` ends at 2.5 s, but `smallparticles5` stops at 1.76667 s with lifetime 1.4 s. |
| Guidance | Target ground | 0.60 | 2 s | Factory close at `96/144 s`, native close duration 1 s; Factory reduces particle lifetime to 0.7 s. |
| Resistance | Target ground | 0.55 | 2.85 s | Factory close at `108/144=0.75 s`, native stop at +0.1 s, particle lifetime 2 s. |
| Light | Target ground | 0.60 | 2 s | Persistent native `main`; explicit local preview close from 1.65 to 2 s, described below. |
| Thaumaturgy | Caster ground | 0.55 | 2.35 s | Factory close at `36/144=0.25 s`, native stop at +0.1 s, `Aura` lifetime 2 s. |
| Shield of Faith | Target ground, facing yaw | 0.50 | 4.5 s | `Init` lasts 4.5 s. Factory switches to `End` at `216/144=1.5 s`; its final particle launch at +1.1 s and lifetime 1.5 s end at source time 4.1 s. |
| True Strike | Caster hand, facing yaw | 0.30 | 1.5 s | No AnimationPlayer. Factory closes at `60/144 s`; particle lifetimes 0.6 and 1 s finish by 1.416667 s. |

The bounds include native particle retirement rather than stopping at exported
sheet length or AnimationPlayer length alone. Factory material envelopes can
finish earlier than these raw emitter bounds. A bound does **not** prove the final
visible sample is occupied: native temporal captures must inspect the actual tail
and excessive empty time separately.

The optical colours come from the selected Factory finishing ramp's fourth
colour. The exact recipe and JSON pointer are stored in `light_color_source`.
They recolour admitted native optical sources; they do not add new light nodes.

### Explicit finite Light preview

The source's `main` holds its orb and light. Its native `oneshot` animation exists,
but the Factory lifecycle selects `main`; the intake does not silently substitute
another animation. `fade_out_seconds=0.35` and `emission_seconds=1.65` author a local
inspection close. Explicit `fade_bindings` drive the donor Glow/Flare material
`alpha_multiplier` and Light node `light_multiplier` from 1 to 0. These controls
are shared by Sequence and the selected isolated phases; the optical bridge must
not apply the envelope twice. Geometry and the corresponding optical light finish
that close together before the instance is retired. This is a finite preview schedule,
not the duration or expiration of the gameplay Light spell.

### True Strike follow-up demonstration

The existing client choreography keeps `cast.enabled=false`; the attack body and
hand layer belong to its `childAttack` authoring. The user's later request adds
an explicit offline `body_actions` entry: after the buff, a Shortsword/Melee3
caster plays `Attack6` with its actual `Magic2` layer, and the adjacent recipient
plays the explicitly selected `TakeDamage` reaction at source contact frame 7.
The attack starts 0.30 s after release while the native hand aura is still active.
It does not assert a successful server attack, roll, advantage, HP change or
condition consumption. The ordinary disabled cast stays disabled; the follow-up
has its own authored owner and timing. The native aura follows the current
actor hand socket through that attack.

## Sources and preserved edits

All recipe paths below are relative to the original VFXFactory root. The importer
copies only their selected dependency closure. Factory originals are unchanged.

- **Aid / Bless:** `recipes/spells/aid.json` and `bless.json`, source
  `library/binbun/pack_binbun_statusfxfull/assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_divine.tscn`.
  Aid uses `factory/components/recipient/healing.gd`: preserve its internal scale
  0.72, height 0.9, particle density and material envelope. Its native sphere
  height 3.4 becomes `3.4 × 0.72 × 0.60 = 1.4688` world units. Bless uses
  `recipient/blessing.gd`, replacing the donor sphere with its existing open-ended
  cylinder (height 2.5, radius 0.8) and adding the broken ground ring. With internal
  scale 0.9 and root 0.55, cylinder height is 1.2375, radius 0.396 and ground-ring
  height 0.0099 world units. These are existing Factory edits, not newly inferred
  game geometry.
- **Cure Wounds / Healing Word:** `recipes/spells/cure_wounds.json` and
  `healing_word.json`, sources
  `library/lelu/pack_lelu_godot_healing_protection_premium/VFX/Scenes/VFX_HealPuff_A.tscn`
  and `VFX_Healing_W1.tscn`. Preserve `recipient/support.gd`'s selected layers,
  five-puff burst, muted horizontal line, pulse shape, source lights and animation
  keys. Their Factory scales/heights are 0.8/1.2 and 0.85/0.35 respectively.
- **Guidance / Resistance / Thaumaturgy:** `recipes/spells/guidance.json`,
  `resistance.json`, `thaumaturgy.json`, from the same Binbun StatusFX directory:
  `vfx_status_magic.tscn`, `vfx_status_dark.tscn`, `vfx_status_glow.tscn`.
  Preserve Factory scale/height pairs 0.42/1.35, 0.75/0.9 and 0.18/1.6. Guidance's
  existing edit reduces inward particles to three with 0.7 s lifetime. At the
  proposed root scales, its magic card height/centre are 0.756/0.81; Resistance's
  sphere height/centre are 1.4025/0.495; Thaumaturgy's glow card height/centre are
  0.2475/0.88 world units. Some source envelopes extend below their ground anchor;
  the intake does not fabricate offsets to conceal that source geometry.
- **Light:** `recipes/spells/light.json`, source
  `library/binbun/pack_binbun_godotmagicorbsvfx/assets/BinbunVFX/magic_orbs/effects/magic_orb_small/magic_orb_small_vfx_03.tscn`.
  Preserve the Factory's hidden Flare, Glow gradient/fresnel edits and disabled
  proximity fade. Internal scale 0.18 and height 2.35 with root 0.60 give a 0.1512
  diameter orb centred 1.41 world units above the recipient anchor.
- **Shield of Faith:** `recipes/spells/shield_of_faith.json`, source
  `library/lelu/pack_lelu_godot_healing_protection_premium/VFX/Scenes/VFX_Protection_4_Shield.tscn`.
  Preserve the Factory's muzzle/ring/particle choices and hidden extra flashes.
  The shield's existing local height `(0.996 + 1)` with internal scale 0.78 and
  root 0.50 gives centre height 0.77844 world units. Preserve its native facing;
  apply recipient yaw, not projectile pitch.
- **True Strike:** `recipes/spells/true_strike.json`, source
  `library/lelu/pack_lelu_godot_weapon_effects_premium/VFX/Scenes/VFX_Dark_sword.tscn`.
  Preserve the hidden `PurpleSword` mesh and remaining `pFire`/`extra` particles.
  Factory scale 1.8 and root 0.30 yield total scale 0.54. This source has no player;
  it is a particle/material aura, not a standalone weapon animation.

## Shared intake requirements

1. `profiles.finishing.colors` is the actual palette source for all ten recipes.
   Each batch entry copies it explicitly into `palette.ramp` and records its JSON
   pointer. Preserve the native smooth finishing path; export `block_pixels`,
   hard alpha/energy cuts and nearest-colour quantization are not imported.
2. `phases.*.component_overrides` must merge before constructing the phase. Bless
   sustain genuinely changes `mode=sustain`, `close=0`, `frames=289`; copying only
   the top-level component would silently show the lifecycle again.
3. `front` and `back` are export halves. The resolver selects the back recipe once
   and sets `side=full`. The copied `recipient/blessing.gd` override must honour
   that full side too; its original override otherwise inserts the half-space
   test unconditionally. The original Factory script remains intact.
4. Preserve the component's native lifecycle, initialization and authored particle
   speed multipliers. Ground placement, source-unit conversion, animated lights
   and source clocks remain owned by the existing sandbox/Factory adapters.
5. Optional phases are availability, not extra mandatory tracks. Their separate
   inspection mode must not turn a preview-only sustain into a gameplay condition
   or a production-frame selection into a second simultaneous effect.

## Verification boundary

A read-only check using the actual `tools/prepare_projectile_sandbox.py.resolve`
function found **10 capabilities, 18 selected native phases, no missing selected
IDs/scenes/component scripts, and no palette or Resource identity mismatch**.
It also confirmed the resolved Bless sustain retains all three phase overrides:
`mode=sustain`, `close=0`, `frames=289`. Cue scale/rate/end values are finite and
positive; each Sequence references an explicitly selected attached phase.

Native import, four-view temporal rendering, source light/geometry retirement,
phase isolation, pause/recast and loop cleanup belong to the parent integration
run. Those are still required: source review and structural checks are not visual
acceptance. No GPU process was started by this source-intake task.

## First capture review and integration corrections

The first view-0 support captures exposed three source/integration issues; they
were not accepted as finished artwork. The copied StatusFX `streaks.gdshader`
billboard replaced the model basis with unit camera axes, dropping inherited
Factory and root scale. Its copied shader now preserves each model-axis length;
shrinking the staging values would have hidden the cause. The Light ending still
showed a solid orb and full illumination, motivating the explicit native control
bindings above. True Strike used a generic release marker above the head because
its disabled cast has no preparation sockets; the sandbox now uses the existing
current-pose `pose_sockets.hand.Idle` data. These changes require the parent's
subsequent native captures for visual acceptance.

Bless's initial ending capture had no remaining ground ring; its broken ring
during playback is authored source geometry. Aid, Resistance and Shield appeared
reasonably placed in that view. Cure Wounds and Healing Word remain lower-leg /
ground bursts, consistent with their preserved Factory heights. This observation
is not four-view approval.

## Native integration follow-up

Root completed the combined 20-spell four-view native suite (1510 checks), all 31
isolated phases, and retained the original 14-spell regressions (1368 checks).
Sacred Flame's later full-beam framing passed 90 further checks. All source-review
blockers raised for this batch were corrected; see sandbox/README.md and the
`.runtime/sandbox-batch-all 20-checks.json`/framing reports for precise evidence.
The finite holds are offline presentation fixtures, not invented gameplay duration.


## User correction pass: 14 October 2026

These changes follow the user's review of the actual native preview. Historical
source/export registrations above remain provenance; the active bindings in
`support.json` now explicitly differ where described here.

- **Aid and Bless:** preserve the application, then lower sustained opacity to
  0.20 and 0.18 respectively, in addition to the original source envelopes.
  Isolated Bless Sustain starts quiet. Aid's sphere bottom was 0.1944 world cells
  below the floor; adding 0.45 source units only to its Mesh aligns the bottom
  exactly. Bless's cylinder bottom was 0.06875 world cells above the floor; lowering
  only that Mesh by 0.1388889 source units aligns it without moving its ground seal.
- **Cure Wounds and Healing Word:** attach to the existing reconstructed body
  socket. Remove donor export height 1.2/0.35; center Healing Word's principal
  pulse emitter at its local origin. Native lifetimes and surrounding flecks stay
  authored by the selected source.
- **Guidance and Thaumaturgy:** their actual original sheets and source scenes
  contain a flat billboard streak card. Replace only that card with a Godot
  SphereMesh of the same source width/height, retain its real animated material,
  and disable its existing billboard/proximity switches. This is an explicit
  3D adaptation, not a claim that the original donor was volumetric.
- **Resistance:** the engine's `ResistanceEffect` and old support authoring define
  a neutral one-use 1d4 saving-throw bonus, with one blue/neutral front/back pair.
  The source export at `exports/recipient-production-sampling-01/010-spell.resistance-front-production_impact-E/E_0072.png`
  agrees. There are no elemental variants in this spell's data; it is not
  Protection from Energy or Elemental Affinity.
- **Light:** the orb and its actual native light remain coincident at 1.41 world
  cells above the recipient floor. Native base energy becomes 3 and source range
  13.333333 converts once to 8 world cells. The existing shared cap and three explicit
  geometry/light close bindings are preserved. This is an offline optical
  calibration, not a new gameplay light category.
- **Shield of Faith:** lower only the source shield mesh to local Y 1.25, placing
  its center at 0.4875 world cells. Explicitly exclude `external_base_ring`,
  `verticalflash2` and `muzzle2` donor clutter. Preserve the shield and source
  opening/closing animation.
- **True Strike:** use the explicit follow-up described above, with the catalog
  Shortsword and recipient one cell from the caster. Both actors return to Idle.

All nine nonluminous examples disable decorative room illumination through the
shared source-light multiplier. Their material emission remains a visual source
property. Light alone retains its actual room-light contribution.

`tests/sandbox_support_authoring_checks.gd` constructs all 18 selected native
phases and samples their actual geometry and optical anchors. It passed 106 checks
with no failures, including floor alignment within 6e-8 world units and unchanged
source-phase availability. `tests/sandbox_utility_feedback_checks.gd` adds actual
native-window evidence for all 10 spells/four views: source visibility against a
same-time hidden-source frame, quiet holds, torso attachments, volume in each
view, actual Light on/off receiver differences, and the attack/hand-layer/reaction
sequence. The coordinated Windows Forward+ run passed **792 checks, zero
failures**, across all 10 spells and all four views. It exited cleanly; the user's
preview was left open and untouched. Evidence is in
`.runtime/sandbox-utility-feedback-checks.json`,
`.runtime/sandbox-utility-feedback.log` and `.captures/utility-feedback/`.

The actual rendered activation/active frames were inspected in all four views.
The healing effects sit on the torso; Guidance and Thaumaturgy remain visible
without the former edge-on card disappearance; Shield of Faith sits around the
waist. Light's same-frame optical on/off comparison visibly changes the floor
and actors while its orb stays above the head. True Strike shows the adjacent
Attack6, the target's TakeDamage pose and the authored child hand layer; this is
an explicit offline visual example, not a server attack result. Ending/complete
captures and lifecycle checks show source cleanup and eventual Idle restoration.

Aid's hold is visibly subdued. Bless's hold is measurably quieter than its
same-time unattenuated reference, but it remains a conspicuous gold body-height
effect. The native checks establish that its authored envelope takes effect;
they do not establish user approval of that remaining visual prominence. See
`bless-v0-quiet.png` and `bless-v0-unattenuated-reference.png` in the capture
directory before treating the persistent Bless look as final.

### Bless sustained-opacity follow-up, 15 October

The .18 hold above remained too prominent in the rendered review. Sequence,
isolated Lifecycle and isolated Sustain now use .05 for the sustained multiplier;
the full application, source timing, material colours, floor registration and
native close are unchanged. The source-geometry suite still passes 106/106.
After the coordinated import, the Bless-only four-view native run passed
**76/76 checks**, exited cleanly and left the user's preview untouched. Actual
frame review confirms a darker, more transparent hold with the actor readable;
the gold bands remain visible by design. The measured final-frame source
luminance contribution at the hold is 52–53% of the previous .18 pass across the
four views. The opening retains its full source envelope. See
`.runtime/sandbox-bless-opacity005-native-checks.json`, the matching `.log`, and
`.captures/utility-feedback/bless-opacity-comparison.jpg`. These are rendered
qualification results, not a claim of final user art approval.

The earlier 792-check result and log are preserved separately as
`.runtime/sandbox-utility-feedback-all10-opacity018-checks.json` and the matching
`.log`; its Bless frames are in `.captures/utility-feedback/bless-opacity018/`.

### Current Bless sustain: body surface, 15 October

The user reviewed that comparison and explicitly requested the sustained effect
on the body instead of a surrounding cage. Both opacity-only attempts above are
therefore historical. Bless now follows the same shared `body_surface` path as
False Life, with no new shader branch or lighting system.

The original native application remains an independent source cue. Its existing
Factory colour, noise, particles and full opening are preserved. The original
`game_obsolete/data/condition-media.json` `pending.bless` application fade
(1500–2000 ms) defines the handoff: the native source fades out by two seconds;
the actual selected sustain source begins at 1.5 seconds and fades onto the
assembled recipient during that half-second overlap.

The sustain reads `effect/Donor/Mesh`'s actual noise texture, post-Factory
primary/secondary/tertiary colours, scrolling/twisting parameters, emission,
`support_clock` and `support_envelope`. Its complete source geometry stays hidden,
including the cylinder and ground seal. The shared receiving path projects that
material through the recipient's delivered depth, normals and painted alpha.
Projection scale is 1.5; nominal strength 1 multiplies the original .49 native
envelope and .25 authored hold once, for a maximum .1225 body film. Decorative
room illumination remains zero. Isolated Sustain uses the same body path.

The finite sustain sample lasts 3.6 seconds with a .35-second final fade,
preserving the prior 5.1-second total source demonstration. This is an offline
inspection interval, not a gameplay Bless expiry. The source suite passes
114/114, including the actual native texture, colour fields, envelope and
animated clock. The utility fixture now measures actual body pixels at hold
instead of demanding a visible source cage. Four-view native containment,
depth/normal response, phase handoff and cleanup are pending the coordinated
combined body-surface run.
