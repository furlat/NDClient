# Native VFX Factory → Godot client handoff

Current working contract, 15 October 2026. This describes the implemented offline
sandbox and the current30-capability production migration, not a new protocol or
a declaration that every effect is finished. Aid, Bless, False Life and Sacred
Flame remain excluded from the production activation batch.

## User acceptance — outstanding work

**Aid, Bless, False Life and Sacred Flame are NOT accepted by the user.** Their
current effects still need artistic work and another user review. The implemented
body-surface treatments for Bless and False Life do not change that status.

**Timing and positioning need tuning for ALL spells.** This includes preparation,
release, travel/contact, recovery and persistent phases, together with hand/body/
ground anchors across casting animations and camera views. Current values are
editable working values, not approved final choices.

Technical checks below establish only their stated behavior (for example source
registration, body-mask containment, clocks, stacking and cleanup). Passing them
does not establish visual acceptance. Client/Studio migration must preserve these
outstanding items and make the effects available for further authoring; it must
not present the current appearances as user-approved or finished.

Proposed replacement runtime shape (not yet accepted): [NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md](NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md).

## Start here

- Client: `C:/Users/tommaso/Documents/Dev/NDClientGodot`.
- Factory: `C:/Users/tommaso/Documents/assets/VFXFactory`.
- Run `spell-sandbox.cmd` or open `spell-sandbox.tscn` in Godot. The launcher uses
  Windows Godot 4.7.2, Forward+/Vulkan.
- The selected manifest currently contains **34 capabilities / 78 native phases**.
  The second False Life phase is a separate sustain source.
- The fixture uses the player's real modular sprite/depth/normal renderer and a
  native 3D effect pass. Actors/targets are hand-placed. No backend session,
  fabricated server events, damage amounts or simulated rules are involved.

Sequence plays the whole presentation; individual phases isolate the original
sources. R recasts, Space pauses, Q/E rotate. Placement mode edits the target;
Shift-click edits the caster. Flight speed changes travel independently of cast
animation speed. Source-piece toggles are inspection overrides, not saved choices.

## Owners: edit these, not generated copies

| Concern | Current owner |
| --- | --- |
| Native meshes, particles, shaders, AnimationPlayers, lights and composition | Factory `recipes/spells/*.json`, `recipes/projectile-windups/*.json`, their component scripts/scenes/resources |
| Original body/hand animation and spell material choices | Client `authoring/spells/spell.<id>.json` and `authoring/catalog/rigs.json` |
| Original fourteen spell cue schedules | `authoring/sandbox/staging.json` |
| Additional twenty source selections, phase overrides and schedules | `authoring/sandbox/batches/{support,combat}.json` |
| Source recovery, native variants and explicit import corrections | `authoring/sandbox/projectile_additions.json` |
| Optional casting profiles | `authoring/sandbox/casting.json` + `sandbox/casting.gd` |
| Inspectable spell identity, scale, lead/tail and selected casting profile | `authoring/sandbox/*.tres` using `sandbox/spell.gd` |
| Native receiving body-material selections | `authoring/sandbox/body_materials.json` |
| Hand-only policy and colour-treatment hit envelope | `authoring/sandbox/feedback.json` |
| Generated selected source manifest / copied dependencies | `authoring/sandbox/projectiles.json` / `assets/native_effects/sandbox/projectiles/` |

Do not hand-edit the generated manifest or copied artwork. The import script
copies only the selected dependency closure; source assets remain gitignored.
Factory originals are not changed by the client importer.

## Source and clip inputs

The importer reads existing `vfxfactory.spell.v1` recipes. Relevant existing fields
are `variants`, `components`, `phases`, and `profiles.clock` / `profiles.palette_pass`.
A phase selects component IDs, optional `component_overrides`, sample `bindings`
(`component`, `kind: "sample"`, `rate`, `offset_seconds`) and emitter settings.
Components identify `script` and `input`, commonly `input.scene` and its settings.
The component script provides `make_component(input)` and the resulting node's
`sample(seconds)`. Native resources remain native; this path does not export sheets.

Resolved clip IDs are `<recipe-directory>/<recipe-name>/<variant>/<phase>`;
selected windups have their existing `/windup` suffix. The generated record keeps
`components`, `bindings`, `emitters`, `seconds`, `simulation_hz`, source recipe and
variant. Batch entries explicitly name `sources` and `select_clips`. Their
`clip_overrides` provide the isolated-phase `placement`, labels and necessary
source registration. They are not inferred from what happened to render.

Native composition uses `side: "full"`; old front/back exports are not two effects.
Declare recovered material/animation bindings explicitly. Dynamic resource paths
must be reachable from the selected dependency closure. Inspect shader sampler
defaults as well as explicit material parameters: replacing a VisualShader clock
or duplicating a material must retain its noise/ramp textures.

## Timing, attachment and lifetime

`sandbox/choreography.gd` resolves the existing cue data. These are presentation
clocks, distinct from server ordering and from source animation seconds.

| Existing cue fields | Meaning |
| --- | --- |
| `role` | `cast`, `flight`, `strike`, `spray`, `impact`, `area`, or `attached` |
| `before_release`, `charge_seconds` | Buildup window, bounded by the authored preparation pose |
| `source_launch`, `source_contact`, `source_end`, `source_rate` | Native source timing; flight retimes charge/travel, then lets its tail advance at normal source rate |
| `at`, `delay_seconds`, `contact_delay` | Attached phase clock or impact offset |
| `attachment` | `caster_hand`, fixed `caster_release`, `caster_ground`, `recipient_body`, or `recipient_ground` |
| `scale`, `orientation`, `rotation_degrees`, `offset`, `origin_path` | Uniform source-unit conversion and explicit registration, including the actual native core origin |
| `stop_emission_at_release/contact`, `emission_seconds`, `release_hide`, `contact_hide` | Stop new particles / retire named cores while preserving existing tails |
| `opacity_keys`, `fade_out_seconds`, `opacity_uniform`, `fade_bindings` | Explicit preview envelope using actual native shader/light controls |
| `duration_policy: "authored"` | A deliberately bounded inspection hold, not a gameplay condition duration |

Native AnimationPlayer lengths and particle decay extend normal tails beyond a
sprite export's capture window. Source nodes are sampled manually. Particle time
uses the actual native render delta; duplicate paused samples must not advance or
erase a queued draw. Moving trails have separate elapsed-flight history, excluding
the hand's charging motion. Source-internal translation must be registered once
through the existing carrier/origin controls, not added to world travel twice.

Multiple deliveries (`deliveries`, `delivery_interval`, `bends`) and delayed
secondary contacts remain data. `body_actions` supplies explicit local inspection
follow-ups such as True Strike's attack or Shield's probe. Those are sandbox
examples, not authoritative combat outcomes.

## Casting poses and sockets

The original spell recipe remains the default (`casting_profile: "authored"`).
Five established spell-casting poses are available for deliberate inspection:
Attack1, Attack4, Attack5, Attack6 and Special1. A profile owns its
prepare/release/recover frames, speed, matching Magic2 sheet and directional hand
paths; it replaces both `cast.sourceSockets` and `projectile.sourceSockets`.
Source frames are zero-based at the selected rig clip FPS. All eight facings need
the same release point as `preparation[releaseFrame]`.

Attack2 and the bow-like Attack3 are excluded. Native 3D effects can be repositioned,
oriented and registered to the existing selected pose; that flexibility does not
automatically reassign a spell's authored animation. Attack4's optional charge
starts at7 because its original frame6 lacks the E-facing hand. Attack6 uses Burning Hands' corrected Magic2 hand,
not the generic socket on the other arm. Both-hand magic centroids are not hand
anchors. Open Arm Invocation (`Special1`) deliberately uses the midpoint of both
authored hands, six source pixels forward from the body. Each hand's optical
depth is resolved before taking that midpoint; it does not borrow torso depth.
Existing spell defaults and artwork stay unchanged.

`sandbox/surface_sockets.gd` resolves the requested pose's painted owner and optical
depth. Missing support retains the painted anchor and reports the gap. Caster
body auras are excluded: only Magic1/2/3 hand layers are currently requested.

## Colour, lights and receiving body surfaces

Native effect finishing retains a supplied ordered colour ramp with smooth,
premultiplied edges. An export quantization table is not an ordered brightness ramp.
Pixel blocks and export cutoffs are disabled. No-ramp sources retain native colour.

Source OmniLights retain their animated position, range, energy, colour and height.
`sandbox/light_units.gd` converts native lengths once; `source_lights.gd` bridges
them to the player's normal-lit PointLight2D atlas and existing cap. Native Light3D
illuminates native effect geometry only. Optional `light_color` and
`decorative_light_multiplier` are explicit staging choices. The optical cookie is
a smooth source-centred GradientTexture2D approximation, not exact OmniLight3D
attenuation or new gameplay light state. Spot/directional/subtractive effect-light
bridges are unsupported. The approved ordinary room lighting is unchanged.

Receiver feedback offers colour treatment and **full native spell material**.
Both use the restored 150 ms hit envelope (50 ms hold, 100 ms fade).
The latter selects `clip`, `node`, `surface`, `clock_parameter` and explicit
`parameter_overrides` from `body_materials.json`. `sandbox/body_material.gd`
evaluates that actual material on an independent per-recipient 256×256 surface;
the existing renderer applies it within the assembled actor silhouette. Its clock
starts at the receiving hit age. It is the chosen material, not the entire native
projectile composition. TakeDamage is separate and survives disabling the flash.

Currently 12 of 16 damaging spells have this native body mapping. Burning Hands,
Chill Touch, Poison Spray and Shocking Grasp explicitly fall back to colour
treatment: their materials require particle or geometry inputs that a plain body
surface cannot honestly replace. Reasons live in the mapping. False Life now
transitions from native application to body-conforming sustain; its separate
framebuffer/lifetime checks pass. The previous small mesh sustain is superseded.
Bless now applies the same distinction: retain its native cast/application burst,
then replace the lingering cage with a body-conforming treatment. Both sources'
application/hold transitions and native body output are qualified below.

The saved sustain cue now declares `body_surface: {node, surface, scale, strength}`
in both sequence and isolated placement. `sandbox/body_surface.gd` reads the
selected native support material's noise, three colours, noise scale/scroll/twist,
waviness, emission, `support_clock` and final `support_envelope`. The shared
`presentation/body_surface.gdshaderinc` projects that treatment over the delivered
actor-space surface/normal data; the donor envelope mesh is hidden. This is an
explicit body-conforming adaptation of the support material, distinct from the
full native hit-material quad above. It does not claim arbitrary shader transfer.

The current stacking correction uses one shared actor pass for ordered body
surfaces, with independent source textures/clocks and source-over composition;
the full-native receiving hit is applied last. The separate Colour treatment
retains its existing pre-lighting path in `character_material.gdshader`. The
explicit GPU capacity is eight
surfaces, with overflow reported rather than silently dropping entries. Existing
condition composition still decides the active set/order; this adds no gameplay
condition arbitration or per-condition scene nodes. Native overlap/removal checks
pass, including exact restoration when one layer is removed.

The [placement audit](SANDBOX_POSITION_AUDIT.md) records all 34 capabilities and
the exact source→registration→scale/orientation→socket chain. Source anchors and
forward axes must be deliberate data; a whole effect's visual AABB centre is not
automatically its emission/contact point.
Its focused native suite passes226 checks for actual held/release/contact and
isolated core registration across four views. Magic Missile's retained export
offset, Fireball's windup axis, Ray's shared head anchor and isolated registration
are corrected. Thirty-six actual captures were inspected for visible continuity;
see `.runtime/sandbox-position-checks.json` and `.captures/positions/`.

## Factory author iteration and delivery

1. Edit the actual Factory recipe/component/resources for the selected effect.
   Preserve useful native phases, including preparation, release and tail. Name
   registration nodes and source clock/contact meaning explicitly.
2. Select its existing recipe/clip IDs in the client batch or additions data.
   Adjust cue timing/placement using the fields above. Include isolated `placement`
   so inspection does not depend on running the whole sequence first.
3. Run from the client root:

   ```sh
   python3 tools/prepare_projectile_sandbox.py --factory /mnt/c/Users/tommaso/Documents/assets/VFXFactory
   ```

4. Inspect the real fixture in all four views: hand charge/release continuity,
   moving source, contact and receiver, then complete retirement. Check pause,
   recast, loop and different flight speeds. Inspect raw source colours separately.
5. Deliver the selected recipe/resources and a small change to the existing
   selection/staging/material files, plus the tested clip IDs and remaining gaps.
   No whole-library export, sprite-sheet export, or additional manifest protocol
   is required. Put reusable source fixes in Factory; keep inspection attachment
   and gameplay presentation choices in client authoring.

Relevant finite checks are `--choreography-check`, `--batch-check`,
`--scene-integration-check`, `--particle-clock-check`, and `--casting-check` on the
sandbox launcher. Standalone tests include `sandbox_casting_checks.gd`,
`sandbox_flash_playback_checks.gd -- --all-capabilities`, and the support/utility
feedback tests under `tests/`. Reports are `.runtime/` or `generated/`; captures
are `.captures/`. Use their named scope, not an old aggregate count as proof.
Casting's headless checks pass. The post-fix full-library native material run
passes 4,794 checks: two real 1× Fire Bolt playback cycles, every contact mapping,
12 nonblank native body surfaces, mode switching, pause/recast and expiry. Fireball
can obscure its whole recipient at contact; a separately labelled source-hidden
control verifies that body output without pretending it is visible through the
explosion. False Life passes 262 native checks across four views, two actual Idle
frames and isolated sustain: visible film stays within painted actor coverage,
uses delivered depth/normals, and clears on expiry, recast and spell changes.
The native five-pose/four-view casting check passes 203 checks, including real
hand/core release, exact original JSON restoration, and retention of placement,
zoom and flight speed during a pose-only change. The earlier seven-pose run is
superseded by the user's approved-pose scope and corrected camera setup. The
combined False Life/Bless/body-stack suite passes830 native checks: independent
source clocks/material inputs, four views and two Idle frames, application-to-film
handoff, isolated sustain, loop/unload/expiry/recast, containment, exact layer
removal and explicit capacity/missing-input handling. Sixteen pre/post-stack False
Life scene comparisons are byte-identical. Reports are
`.runtime/sandbox-body-surface-bless-stacking-830.json` and
`.runtime/body-surface-single-layer-parity.json`. Run GPU suites
sequentially; preserve an active user preview unless the user authorizes its restart.

## Bringing this into the main client

The sandbox reuses rendering, but `sandbox/choreography.gd` is not the SDK reducer.
The existing production owners are `presentation/components.gd`,
`presentation/native_effects.gd`, and `authoring/native_effects/index.json`.
That index retains the class/blood sources and now has a separate `spells` table
for all30 non-deferred capabilities in the existing sandbox batch. It selects
the existing native manifest and flat/nested staging data, plus measured source
bounds/light inspection metadata. The four explicitly deferred capabilities
remain outside that registration. Registration alone does not certify each
recorded/native rendering path. See
[the migration plan](NATIVE_SPELL_CLIENT_MIGRATION_PLAN_2026-10-15.md) for current
qualification and the next ownership chunks.

Production integration must bind selected native sources to actual ordered
server events and persistent conditions through those existing owners, including
source contacts, cancellation/removal, recipients, replay seeking and faction
visibility. Reuse qualified source adapters and authoring instead of copying the
offline fixture's contacts or local body actions into gameplay. Renderer tracks
must expose every resulting layer/light/body treatment, including missing ones.

The shared native source, phase-clock, placement, light and hit-material helpers
now live under `presentation/`; the sandbox delegates those mechanisms while
retaining its offline choreography. Production never imports the sandbox's
delivery counts, synthetic contacts, test body actions or fixed condition holds.
The real client's settings and Studio's Inspect menu expose the Colour/full spell
material choice. Damage remains authoritative and uses the shared 150 ms envelope.

Studio native phase previews sample actual Factory sources. Source-light child
rows retain exact native property keys; body-material children retain actual
applied-damage ownership. A dedicated assembled-body material thumbnail remains
an explicit gap; the actual receiver can be inspected in the replay. Source
availability is separate from post-draw evidence and from user acceptance.

The initial Fire Bolt/Magic Missile slice passed the real-recording acceptance on Windows
Forward+/Vulkan: 3347 playback checks, 504 native thumbnail checks, eight actual
Studio checks and 68 independent-pane checks. This covers recorded hits and
Shield blocks, correct recipients, source clocks/tails, exact paused hit-choice
restoration, seeking, looping and cleanup. The migration plan records fixtures,
reports and remaining integration limits. This is technical qualification, not
artistic approval of the remaining spells.


The current batch adds transient cast/flight/strike/spray/area/attached phases and
real condition/spatial-effect ownership through the same reducer and presenter.
No sandbox hostile probe, recipient count or follow-up body action becomes a
gameplay event. Shield contact follows actual interception facts; Ice Knife's
area effect follows its distinct recorded burst; the native Light visual shares
the authoritative optical state without adding duplicate illumination.

Persistent sources currently hold an inspected native pose between their real
opening and closing windows. The source's finite demonstration length is never
the condition duration. This is a functional lifecycle adaptation, not approval
of new sustain loops or final visual treatment. Web ground coverage uses disclosed
unsuppressed cells; its separate restrained-recipient visual remains separately
owned. Batch qualification is recorded in the migration plan as it completes.

The current depth/Decal integration covers the fixture's floor cells and opaque
modular actors. Scenery coverage, transparent bodies, scene-colour/refraction,
normal/ORM decal relighting, particle collision and spell audio are not certified
by this sandbox. These limits do not justify adding another rules engine or
changing the approved base renderer while wiring native effects.

Actual batch Studio navigation is recorded in
`generated/native_spell_library_checks.json`: real Fireball, Mage Armor and Shield
Library selection, native source previews, reverse/reseek and selected interval
loops. Corrected Fireball and final Shield each pass 35 checks; Mage Armor passed
in the retained original multi-case run. The report preserves the original
Fireball tail failure and a later test-harness failure rather than collapsing
them into a fictional single green run. Native thumbnail histories now prepare
in bounded batches of eight private worlds at the unchanged 60 Hz source step:
Fireball's 52 visible/all-view samples initially took 20.628 seconds versus roughly
80 seconds serially. The user rejected that intermediate latency. Studio now
loads previously baked Godot preview Resources from disk, generated by the same
sampler without changing source clocks or output quality. Run
`bake-studio-previews.cmd` after source changes, or `--only=fireball` to regenerate
one selection. All 30 integrated spells and the additional real Gallery expedition
have been baked for all four camera quarters. Preview generation is offline;
actual game and Studio world effects continue to use live native sources.

The all-30 integration report is `generated/studio_spell_batch_checks.json`
(3,387 checks, both real audience journals). Native frame/seek evidence for every
spell is in `generated/native_spell_batch_render_checks.json`, including earlier
failures and their focused corrections. These establish functional integration;
they do not change the four artistic deferrals or imply that every timing and
placement has been accepted. The migration plan records fresh-process preview
load timings, actual Library navigation, the large-map run and remaining limits.

The final saved-resource Fireball Library check passes 36 checks: its 52 visible
source samples load in 80 ms, with no native preview jobs or missing samples.
Complete case publication remains 3.8 seconds, including journal indexing and
world preparation. A separate fresh-process Resource suite passes 100 checks,
including overlapping-page preservation when baking another recording. Exact
planned-tick verification covers all 28,016 library samples and 10,236 Gallery
samples after the final compiler changes, with no misses. These saved images
are source thumbnails; effects in the game and replay remain live native VFX.
