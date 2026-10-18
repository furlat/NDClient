# Native spell sandbox

Run `spell-sandbox.cmd` on Windows, or run `spell-sandbox.tscn` with F6 in Godot.
The launcher explicitly selects Forward+/Vulkan. This is an offline presentation
fixture in the player's World3D, using its actual modular sprites, normals,
2D lighting and four camera views. It creates no server session or gameplay events.

Aid, Bless, False Life and Sacred Flame are **not accepted by the user** and still
need work. Timing and positioning for **all spells** remain to be tuned. Technical
checks are not visual approval; see `agent_docs/NATIVE_VFX_FACTORY_HANDOFF.md`.

## Inspect and author

Select a spell and Sequence, or isolate an original native source phase. R recasts,
Space pauses, Q/E rotate and the wheel zooms. Place actors enables floor placement:
click moves the target, Shift-click the caster. Marker elevation is preserved.
Magic Missile offers repeated or split targets. Flight tiles/s changes travel speed
without changing the casting animation or its source clocks; Speed changes playback.

Pieces lists actual native meshes and emitters, including disabled alternatives.
Toggles are temporary inspection overrides. Hand sockets uses authored preparation
and release poses; disabling it uses the Caster/Release and Target/Impact markers.
The three actor markers accept independent heights. Size scales the selected effect
uniformly; it does not distort individual axes.

Cast defaults to **Authored**, preserving the spell's existing JSON assignment.
The optional Attack1, Attack4, Attack5, Attack6 and Special1 choices change the
body clip, matching hand-magic sheet, preparation/release/recovery timing and
directional sockets together. Attack2 and the bow-like Attack3 are excluded.
Native VFX placement remains independent authoring; changing the pose preserves
target placement, zoom and flight speed.

Permanent choices live in:

- `authoring/sandbox/staging.json`: selected phases, charge/release overlap,
  native axes, world scale, delivery curves, contacts, emission stops and tails.
  Explicit feedback/light colours include their source-material or palette
  provenance when the old sprite authoring or donor hue differs.
- `authoring/sandbox/batches/*.json`: the next twenty native source selections,
  recipient/hand/body/ground attachment, contact, finite preview holds and closes.
  Every source phase has an explicit placement for isolated inspection.
- `authoring/sandbox/*.tres`: spell identity, clock lead/tail and inspection scale.
- `authoring/sandbox/projectile_additions.json`: explicit native source selections,
  recovered import bindings and narrowly declared source corrections.
- `authoring/sandbox/casting.json`: the five optional casting profiles.
- `authoring/sandbox/body_materials.json`: native receiver-material selections
  and explicit unsupported-source reasons.
- `authoring/sandbox/projectiles.json`: the last generated source dependency
  manifest of the old import (`assets/native_effects/sandbox/projectiles/`).

This sandbox still reads that manifest and the copied sources as they are. The
importer that produced them (`tools/prepare_projectile_sandbox.py`) was removed
on 18 October: the game and Studio play the Factory's finished VFX package
(`assets/vfx/`, see the main README) and nothing regenerates this manifest.
Reload rereads local authoring.

There are **34 spell capabilities and 78 source phases**. The additional twenty are
Aid, Bless, Bane, Command, Cure Wounds, Healing Word, Guidance, Resistance, Light,
Thaumaturgy, True Strike, Mage Armor, Sanctuary, Shield, Shield of Faith, False Life,
Sacred Flame, Shocking Grasp, Burning Hands and Thunderwave.

The attached-effect cues explicitly select a recipient and hand/body/ground anchor.
Persistent donor sources have bounded, editable **preview** holds and closes; these
are not simulated gameplay condition durations. The same native clocks, anchors
and close controls apply in Sequence and isolated phase inspection. Actual source
AnimationPlayer closing clips are retained where available. Other selected source
controls (shader alpha and native light energy) are authored as fade bindings.

The original fourteen remain available. Ice Knife includes its
secondary burst. Magic Missile uses three curved deliveries; Scorching Ray uses
three rays. Chill Touch is a target-local portal/punch, not an invented projectile.
Its original scene, material, recovered animation, lights and component lifetimes
are retained. Sleep and Web do not invent damaging hits. Area scales are uniform:
Fireball/Sleep use a 20-foot-radius guide, Web a 20-foot-side guide. Animated smoke
and irregular web silhouettes do not exactly equal those gameplay boundaries.

Character hand-magic layers use the existing cast authoring, restricted to
Magic1/2/3 by `authoring/sandbox/feedback.json`; caster body auras are excluded.
Native recipient spell effects remain independent. Damaging contacts sample
TakeDamage and the selected **Colour treatment / Full spell material**. The
colour treatment uses the spell's palette/noise. Feedback authoring
sets a 150 ms lifetime with 50 ms hold and 100 ms smooth fade; screen blending keeps
dark pattern regions from replacing the painted body with black. Gamma and
untinted source controls remain authored. Full spell material evaluates the
selected native shader and textures on a per-recipient surface and applies it
inside the assembled actor's alpha. It preserves the actual material rather
than reconstructing it from the export palette; native vertex geometry is not
transplanted. Twelve of the sixteen damaging capabilities have this mapping.
Burning Hands, Chill Touch, Poison Spray and Shocking Grasp retain colour
treatment because their selected materials require unsupported particle or
geometry inputs. The selector reports the reason instead of substituting a
different material. Spell hit flash is on by default; its toolbar switch disables only the receiver's
material flash. TakeDamage, hand effects and native impacts continue, and the
switch resamples a paused impact immediately without restarting playback. Spell
colours applies the selected Factory colour ramp to cast/travel/impact;
disable it to inspect donor effect/light colours. Chill's feedback uses the
restored original Factory necrotic treatment, also applied to its native hand,
portal and animated source materials. Its export rotation/extra enlargement
stays disabled. The original Chill selection excludes donor ground-slam debris,
cracks and decal while retaining the requested portal/hand. Stage scale is .060
instead of .085.
Isolated damaging impact phases also show receiving feedback; a complete strike
such as Chill waits for its authored source contact rather than flashing at 0.
Pixelation is currently off. Native compositing preserves premultiplied alpha and
soft edges. The sprite-export energy cutoff, alpha cutoff and nearest-palette
quantization are deliberately absent from this native pass; no-ramp sources keep
their original colour. See Godot's [transparent viewport compositing guidance](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html).

### Corrections from the four-view visual review

- Eldritch preparation starts at the authored hand frame. Named Flare/MBall
  source anchors meet at release; the peripheral anticipation ring stays intact.
- Guiding Bolt's native ribbon uses world-space path points with camera-facing
  width, avoiding a second application of the parent's yaw. Its width matches
  the head; its soft edge is no longer cut by the old export alpha threshold.
- Ice Knife uses the original uniformly scaled lance, without the export
  adapter's extra axis stretch. Its native wrapper light is retained in
  `authoring/sandbox/ice_lance_source.tscn`, with its source energy keys retimed
  to the flight. The bounded hand preparation stops emission at release and
  completes its accelerated source/particle clock before impact.
- Ice Knife's native ribbon starts its history at release, then uses elapsed
  flight time rather than the retimed light/mesh clock. Its texture, colour ramp
  and width curve remain. The selected .12-second history replaces the donor's
  .56 seconds: at the default eight tiles/s, the old ribbon stretched 4.48 tiles
  behind a roughly .59-tile knife; the selected ribbon spans .96 tile. This is
  explicit preview duration authoring. The hand's charging motion is excluded.
- Web's native additive torus now uses texture/particle alpha, eliminating the
  solid donut. The separate ground network is retained.
- Produce Flame grows and travels as one instance. The separate tiny rotated
  windup is available for inspection but no longer duplicates the held flame.
- Magic Missile registers its held, travelling and impact cores to the exact
  native anchor, removing the source export offset once. Fireball's windup
  compensates its internal export-facing yaw before aiming toward the target.
  Ray of Frost and its Ice companion share their native head registration.
  Phase isolation uses the same named anchors as Sequence.
- Ray of Frost's additive flare texture has fully opaque alpha, including its
  black texels. Its named native material now uses premultiplied blending with
  zero coverage, preserving additive RGB without opaque particle rectangles.
  Its original billboard, depth tests, texture and scale animation are retained.
  Native compositing preserves that zero-alpha radiance through colour finishing.

`--visual-review` captures charge, release, travel, impact and decay in all four
views for the six reported spell families. `--review-tag=<name>` keeps separate
capture sets; `--review-spells=<comma-separated ids>` narrows an iteration.
Images and actual source/socket/light measurements go under
`.captures/spell-review/<name>/`. The `final` set contains 120 staged captures
plus native-colour comparisons; contact sheets were inspected manually.
The later `ray-premult` four-view set supersedes Ray's captures in `final`.

### Application and sustained effects

Application and persistence have separate authored clocks and envelopes. Native
shader opacity is bound to the actual source uniform, so paused sampling cannot
compound a fade. Mage Armor and Sanctuary use quieter holds without decorative
room-light spill. Sacred Flame is smaller and excludes its opaque floor flashes;
the textured native beam and sparks remain. Shield has an incoming native probe
and contact response; True Strike includes the subsequent attack and receiving
reaction. These are explicit offline inspection sequences, not server outcomes.

False Life and Bless have separate sustain cues sampling their original source
noise, colours and clocks on the character's delivered depth and normals. Source
envelope geometry is hidden; body alpha bounds the treatment. Bless hands off
from its native application over 1.5–2 seconds. These are body-surface adaptations,
separate from the native hit-material option. No extra gameplay light is added.
Expiry, recast, source removal and spell changes clear the treatment.

`presentation/body_surfaces.gd` composes already-selected surface layers, with
independent textures, clocks and envelopes. Ascending `composition.priority`, then
stable source ID, determines source-over order; each layer blends its bounded RGB
with the result below it. The native hit flash is applied afterward. Body alpha
and ordinary lighting remain separate. The current single-pass GPU capacity is
eight surface layers; excess IDs are explicitly reported as
`body_surface_capacity`, not silently overwritten. This is a rendering budget,
not a limit on game conditions. Existing condition ownership, suppression and
recipe-selection rules stay in `Conditions`; production event binding is still
separate work. Godot's [uniform-array support](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#global-arrays)
keeps this in one receiving pass without adding a viewport per persistent effect.

Burning Hands remains fixed at the release point of maximal extension. Shocking
Grasp reuses the original spark source. Healing effects attach to the recipient's
torso, Shield of Faith sits at the waist without the wind rings, and Guidance and
Thaumaturgy use volumetric geometry visible from all four views. Light's actual
emitter shares the orb's world height and converted radius. Resistance remains
the saving-throw cantrip rather than elemental protection.

## Scene integration

The painted renderer keeps its approved source-over order and 2D normal lighting.
Native effects now receive depth, surface coordinates and optical light integration:

1. Actual floor cells supply their world support heights. Actor measurement
   selects the visible outfit component before reading its delivered solid-valid
   optical depth; covered independently inferred layers cannot override it.
2. A GPU pass publishes that composed support as ordinary Forward+ depth for
   the native effect camera. Source shaders retain native depth tests and depth
   texture/proximity fades. A compositor removes only the support colour while
   retaining nearer native opaque effects and all native transparent materials.
3. Godot Decals project onto reconstructed positions in the actual painted
   output. Albedo/emission receiving is qualified; normal/ORM relighting is not.
4. Animated source lights feed the existing PointLight2D atlas and light cap,
   using their position, height, energy and converted range. Explicit optical
   colours match selected spell profiles; otherwise the source colour is used.
   Source nodes retain their authored colours for animation and inspection. Native
   Light3D affects only native effect geometry, preserving donor self-lighting;
   it cannot also illuminate the painted floor or characters.
   Native range/emitter-size properties receive the same unit conversion as
   geometry. Raw animated lengths are retained separately for replay and the
   2D bridge, which prevents cumulative or double scaling. Native light energy is
   restored before source sampling and any authored closing envelope, so a pause
   or repeated sample never compounds a light fade.
   Effect lights use a smooth native GradientTexture2D centred on the projected
   emitter, shaped by source attenuation. They do not borrow the floor-centred
   gameplay brightness bands. This is a 2D optical approximation; it is not exact
   OmniLight3D attenuation. Ordinary room-light calibration is unchanged.
5. Authored hand/body sockets use the exact requested source pose and its painted
   owner. Release reads its future cast frame rather than the current Idle sheet.
   Missing support is reported in `socket_samples`, retaining the painted anchor.

The scene receiver subtracts the packet's optical ground. It does not reuse the
separate shadow system's height compression. Unsupported foreground pixels clear
covered receiver depth; no replacement physical geometry is invented. Translucent
bodies are excluded from opaque support. The full delivery remains optical data,
not a certified physical model for arbitrary outfits. Current support is the
sandbox's opaque actors and floor cells; production scenery migration and
transparent-body compositing are not complete.

Both receiver/effect passes currently disable MSAA because selective clearing
must address the same attachments used by subsequent native transparent draws.
The native pass clears to transparent black: additive RGB at zero alpha is kept
without accidentally adding the room background colour.
Current selected sources do not consume scene colour/normal screen textures;
future refraction needs explicit scene-colour integration. Particle collision,
production event binding and spell sound authoring remain separate work.

## Verification

Run `spell-sandbox.cmd --batch-check` for the additional twenty spells across all
four views, recipient/contact feedback, actual pause/loop/recast, source-phase
visibility, placement and retirement. `--batch-spells=light,command` limits this
suite; `--batch-one-view` skips phase inspection and uses view zero.

Run `spell-sandbox.cmd --scene-integration-check` for actual four-view actor/floor
occlusion, raised support, native depth sampling, source-over ownership, unchanged
base appearance and source-light receiving. `--choreography-check` exercises all
14 complete casts, receiving animations, colour restoration, release overlap,
held-projectile registration, camera rotation, full tails, multiple recipients and
finite loops. Reports are under `.runtime/`; framebuffer evidence is `.captures/`.
`--particle-clock-check` exercises the actual Produce Flame flight at measured
30/120 FPS, with the same requested source clock, paused-frame stability and
unchanged retirement times. GPU particles use the current native frame delta;
their animation age does not depend on the playback step or render cadence.

Headless checks: `tests/sandbox_surface_socket_checks.gd` (actual delivered poses,
unsupported owners and model transforms) and `tests/sandbox_source_light_checks.gd`
(animated source values and native 2D light lifecycle). Native
`tests/native_scene_decal_checks.gd` compares painted receiving with real planes,
including the engine's measured subpixel edge variation.
`tests/sandbox_light_units_checks.gd` compares a lit native donor material against
an ordinary Godot light with explicit world-unit range, including animated replay.

Validated on Windows, Godot 4.7.2 Forward+/Vulkan, RTX 5090:

| Check | Passed | Evidence |
| --- | ---: | --- |
| Full-library receiver mappings, actual Fire Bolt playback, mode switching and cleanup | 4794 | `.runtime/sandbox-flash-playback-checks.json` |
| False Life/Bless burst-to-body transition, four views, independent stacked clocks/removal, depth/normals, loops and hit priority | 830 | `.runtime/sandbox-body-surface-checks.json` |
| Original JSON assignments and five casting profiles (headless) | 2123 | `.runtime/sandbox-casting-checks.json` |
| Five casting poses × four views, actual hand/release continuity and selector preservation | 203 | `.runtime/sandbox-casting-native-checks.json` |
| Native held/release/contact anchors and isolated-phase registration, four views | 226 | `.runtime/sandbox-position-checks.json` |
| Existing condition ownership, selection and source clocks (headless original-source oracle) | 117 | `generated/condition_selection_checks.json` |
| Complete 14-spell playback, four-view regressions and hit-flash toggle | 1368 | `.runtime/sandbox-choreography-checks.json` |
| Revised receiver material, four-view final pixels, late fade, phase isolation and hand-only policy | 150 | `.runtime/sandbox-feedback-checks.json` |
| Revised Ice released-history clock/pixels and Web alpha/interior network, four views | 109 | `.runtime/sandbox-ice-web-checks.json` |
| Original Chill material, selected layers, full source lifecycle and instance isolation (headless) | 25 | `.runtime/sandbox-chill-source-checks.json` |
| Additional 20 spells, four views, contacts, fade energy, phase inspection and loops | 1510 | `.runtime/sandbox-batch-all 20-checks.json` |
| Sacred Flame final full-height framing, four views | 90 | `.runtime/sandbox-batch-framing-checks.json` |
| Actor/floor integration, four views and fractional zoom | 259 | `.runtime/sandbox-scene-integration-checks.json` |
| Native decal receiving | 97 | `generated/native_scene_decal_checks.json` |
| Delivered surface sockets | 108 | `generated/sandbox_surface_socket_checks.json` |
| Shared nearest atlas addressing | 46 | `generated/source_atlas_uv_checks.json` |
| Optical light parameters/lifecycle | 64 | `generated/sandbox_source_light_checks.json` |
| Native soft-edge/additive alpha/colour compositing | 34 | `generated/sandbox_colour_checks.json` |
| Actual particle clock at 30/120 FPS | 34 | `.runtime/sandbox-particle-clock-checks.json` |
| Native light units/cutoff | 60 | `generated/sandbox_light_units_checks.json` |

Source warnings remain for a deprecated donor VisualShader editor property and
Web/Bane runtime image reads;
the latter must be replaced or packaged explicitly before an exported build.

Automated checks qualify their stated behavior, not final artistic approval of
all spells. The older `--sandbox-check`, `--projectile-check`, regression and
particle-scale checks describe earlier inspection checkpoints; rerun and update
those expectations before citing their old counts for this implementation.

Fireball hands off its held mesh at release and preserves the original ember
tail; Poison Spray preparation invokes the donor End animation at its authored
release boundary, retaining the acid/smoke particle tails. Hidden trail allocations
do not extend the clip. These release semantics are explicit cue/source data.

The original twenty-spell batch counts above are historical checkpoints. The
current support and combat corrections are documented in
`agent_docs/SANDBOX_SUPPORT_SOURCE_REVIEW.md` and
`agent_docs/SANDBOX_COMBAT_SOURCE_REVIEW.md`, including superseded captures.
Fireball can obscure the recipient at contact; the native-body suite includes a
separately labelled source-hidden control, not a claim that the flash is visible
through its explosion. Source fidelity and passing checks are not artistic approval.

`agent_docs/NATIVE_VFX_FACTORY_HANDOFF.md` describes the actual authoring owners,
source registration, clocks, body materials and the remaining production boundary.
The sandbox's spells are not automatically registered to main-client SDK events.
`agent_docs/SANDBOX_POSITION_AUDIT.md` records the coordinate chain and source
registration for every current capability, including cases where static mesh
bounds cannot justify an offset correction.
