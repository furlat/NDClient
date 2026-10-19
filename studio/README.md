# Neurodragon Studio

Open `studio.cmd` from the implementation worktree. Studio reads real schema-16
journals from `.runtime/studio-library/index.json`; it does not start a server.
**Library** is the one authoring-organized browser: spells by level/school,
conditions and actions by family, characters, environment, surfaces, items and
rules. Search by label or exact ID. Every current `authoring/server_ids.json` ID
is listed, including capabilities that have no recording yet.

Select a capability or its case to open that exact current recording. The compact
header selects another case in the same category. One faction is rendered;
select another faction to load its own independently reduced original journal.
Stale, failed and missing recordings never silently substitute another scenario.
**Refresh** rereads the current recorder index. The recorder's command is
`tools/studio_cases/record.py --engine <frozen-engine> [--only kind|id|case]`.

The browser keeps four separate facts: source/build coverage, scenario recording,
actual presentation qualification, and visual approval. A recorded case is not
proof that its VFX/provider works or that the user accepted it. Aid, Bless, False
Life and Sacred Flame retain their rejected status. Current unqualified renderer
inputs remain **not assessed**, rather than becoming green from a body animation.

The same production reducer, compiler, authoring, renderer and audio power the
preview. Drag the divider to resize the preview and timeline. The optional Study
panel uses the selected case's explicit expectations; missing expectations are
not invented as timed renderer work. Inspect retains detailed authored-source and
rendering diagnostics without becoming a second recording browser.

Click a track label to play and loop its real interval. Clicking an event includes
its dependent reaction/effect tails. The disclosure triangle only expands rows.
Drag the playhead on the ruler or on its vertical line through the tracks; pointer
motion updates the requested time and release restores that exact authoritative
prefix. Loop is enabled by default; disabling it stops at the true presentation
end. The beginning button returns to the whole study. The exact selected scene
gates publication; optional recording media and thumbnail preparation do not.
Original decoded images from that prepared scene seed the
bounded thumbnail cache. Ordinary previews render in batches of up to eight with
the same shaders. Remaining current-window tracks warm in the background, grouped
by source clip; visible demand takes priority. Expansion, scrolling and zoom retain
the previous complete layout until the new exact samples settle, including its
matching hit-test and scrub geometry. This is bounded preparation, not a claim that
every possible zoom is resident. Divider
resizing preserves orthographic pixel scale.

The timeline opens at **240 pixels per second** so animation previews remain
readable. **Fit** explicitly shows the whole recording; **− / +** and Ctrl-wheel
change the time scale. These controls never change playback speed or duration.
**Follow**, enabled by default beside Loop, keeps both the playhead and the
currently playing component lane in view, including while the next loop prepares. Its action and lane stay
identified in the ruler. Select an actor's track, then **Inspect → Follow selected actor** to keep
that actor centered in the preview; middle-drag returns to manual panning.
Following stops moving the camera while that actor is undisclosed.

The default timeline groups each causal action. Movement occupies one strip using
the renderer's actual track priority, preserving reaction pauses. Repeated native
deliveries share one phase strip with centered source previews; expand it to inspect
each original delivery. Different spell sources remain distinct. Missing work is
summarized per action; **Details** opens the original hierarchy. Neither grouping
nor scrolling changes source duration, event order or the recording.

Opening prepares only the selected faction's original journal. Selecting another
faction loads it on demand and maps the corresponding recorded event/phase; its
numeric presentation time may differ. Each loaded audience retains its own state
and index. The previous preview remains visible during preparation.

Case loading plans the actual recorded body/environment sources, including
later groups, using the production media planners and existing memory budget.
It does not load every possible pose/outfit in the rig library. Selected assets
stay resident across seeks; assets beyond the budget still pass normal exact
readiness when needed. Native VFX preparation uses the selected recording's
actual sources. Sources at the displayed or requested seek time are mandatory;
upcoming sources warm through the existing background budget. Opening no longer
waits for every registered spell source. Native VFX/audio keep their own preparation owners.

The 14 October native interaction run measured first track selection after case
preparation at **148 ms** (previously 2,221 ms), warm seeks at **72–79 ms**, and
prepared camera changes at **21–27 ms**. Cold case media preparation moved from
843 to 1,862 ms, paid once before showing the case; recording indexing is separate.
These are measurements, not a guarantee of zero cold-load latency.

Body-material operations appear separately with their recipient, shader source,
parameters and owning condition. Their source preview is explicitly the composed
actor; diagnostic mute/solo remains scoped to the condition owner. Source readiness
and actual rendered/visual qualification remain different fields.

Condition removal has explicit restoration rows for the composed body pose and
material. Hidden therefore shows crouch returning to idle and opacity returning
to the value selected by the remaining conditions. An instant reset is a point
marker, never an invented fade. Native light lanes expose actual switch keys,
energy, radii and height; Inspect samples the same production light resolver at
the displayed time.

## Find the missing authoring

Open **Inspect → Authored sources / missing work**, or choose **Authoring /
missing sources…** in the interaction selector. It opens on **Missing authoring**.

Each requirement has its owner, next step and exact JSON pointer or native
Resource property. Filter by capability group across the complete authored
catalog, then search by name, effect or field. **Copy selected** copies one requirement; **Copy
filtered** copies the current filtered worklist. Technical JSON is optional.
The full accepted audit is saved to `generated/studio_authoring_worklist.json`.

- **Missing authoring:** empty required assignments and unresolved presentation
  ownership. The current audit enumerates missing persistent actor indicators and backend
  definitions needing an explicit presentation decision. An ownership decision
  may point to an existing child, spatial or item effect; it does not automatically
  require creating a new VFX.
- **Missing sources:** a selected source cannot be resolved or its file is absent.
- **Native migration:** an existing media assignment needs a selected native
  counterpart. The passive audit contains 1,257 distinct media identities,
  1,675 authored references and 659 registration references. These are not counts
  of absent JSON assignments.
- **Renderer gaps:** authoring exists but its mechanism is unsupported.
- **Missing tracks:** a renderer operation exists but Studio does not yet expose it.
- **Not assessed:** declared behavior still needs source-to-renderer tracing.
- **Unexercised:** a declaration/source is present without qualification for the
  relevant occurrence. This is not a rendered-success claim.

All 160 delivered condition recipes are included without needing a replay for
each. State-only and disabled choices remain explicit. Ground conditions with
existing spatial-effect assignments link to those owners instead of requesting
duplicate actor effects.

Selected JSON and native Resources are audited again whenever the worklist opens.
**Reload** rebuilds the recording with external authoring edits. The backend-definition snapshot and
native-provenance audit are explicit offline inputs; regenerate them when those
inputs change:

```sh
# Run in the existing engine Python environment, with dnd_engine on PYTHONPATH.
python tools/studio_content_catalog.py
```

Native-provenance regeneration is documented in `authoring/native_effects/README.md`.
No asset import happens while opening the Studio or this worklist.

## Inspect an occurrence

The lower pane follows event causality, with component and condition subtracks
under their actual owner. Missing components retain their source pointer and
reason. Actual sprite/native previews are shown for supported sources; an absent
preview is not replaced by invented imagery.

The row inspector starts with a short provenance explanation before its details:
recorded server event/state, authored clip/effect/sound choice, or missing
authoring/renderer. An airborne blood response identifies the actual disclosed
`body_release` separately from its selected native source. Ground blood tracks
identify the disclosed `DamageResultFact.body_release.regions` and the exact
tile residue after-values they reveal. The source thumbnail uses the same native
blood renderer. Source availability is never presented as proof of a rendered
or visually qualified occurrence.

Use play/pause, source-sample stepping, speed, loop and fit/zoom controls. **Q/E**
rotates the linked preview cameras. When recorded perspectives differ, Studio
shows two independently reduced worlds on a shared causal timeline. The faction
selector chooses which pane supplies audio; switching it does not reload either
world. Identical rendered perspectives keep one pane. Events retain their split
faction tracks.
Unseen audiences and empty branches take no rows in the default timeline. A
single useful view is shown directly; split labels remain only for meaningful
alternate presentations. Both panes preserve the selected occurrence and phase, including an unseen
event whose other view has no animation duration. Omitted intervals hold the
unaffected view without changing source animation rates. Technical
metadata and detailed missing-source explanations stay in the inspector. The existing Invisibility case is
under **Conditions → Perception**.

## Native authoring and the shared event pipeline

### Saved native timeline previews

Native spell timeline thumbnails are baked separately from interactive playback:

```bat
bake-studio-previews.cmd
rem Rebuild only an edited spell; unchanged source pages are reused.
bake-studio-previews.cmd --only=fireball
rem Add previews for a new recorded sequence.
bake-studio-previews.cmd --recording=res://.runtime/my-case/amber/journal
```

The baker reads the existing recorded cases and saves compressed Godot `.res`
Resources under `.derived/studio-native-previews/`. These contain the rendered
RGBA frames, source specification, fixed source timestamps and camera quarter.
Each page holds at most64 frames; the runtime Resource cache retains at most64MiB,
in addition to the existing bounded visible-thumbnail cache. The files are local
derived artwork and remain Git-ignored. They survive Studio/app restarts. Source
or visual-authoring changes invalidate the affected previews on the next index
reload; unavailable samples use the existing native preview fallback. The main
game still renders live native effects.

Run the baker with `--plan-only` for a no-render inventory or `--force` to replace
the selected derived previews. Baking uses the same native source sampler and
one forward history per phase/view, retaining the existing source sampling and
128-pixel published thumbnails. It does not run a backend encounter.

The full 30-spell bake took 175 seconds once. A subsequent actual Fireball Library
test loaded its visible source previews in **80 ms**, with zero native simulation
jobs and zero misses. Whole-case publication took **3.8 seconds**, including
recording indexing and world preparation; the thumbnail result does not claim
that opening a complete case takes 80 ms.

One Gallery destruction asset has a numeric depth/normal sheet wider than the
GPU's texture limit. `tools/prepare_environment_texture_layout.py` losslessly
reflows its original cells into `.derived/environment-texture-layouts/` and writes
the lookup in `generated/environment_texture_layouts.json`. Run it once with a
Python environment containing Pillow when preparing a fresh artwork checkout.
It preserves every source pixel, frame, pivot and animation clock; it neither
resizes artwork nor changes its lighting. Runtime upload readiness checks the
device limit and reports oversized images before attempting a GPU upload.

### Large-map spell run

The recorded **Sorcerer expedition · Lantern Gallery** study (`GAL01`) contains
60 successful SDK commands on the existing large map. It includes the entrance
door, movement through the furnished hall, six spell types, an enemy Magic Missile
that triggers the Sorcerer's Shield, real damage and environment destruction,
then Dash and further movement. Both original faction journals are retained.
Open it from Library or the **Spell composition → Large-map expedition** selectors.
The playback lasts 42.85 seconds; it does not need a running backend.

For this local captured run, start with actor and track following enabled:

```bat
studio.cmd --recording=res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal --follow-actor=d9d66cc6-2e1b-4180-91a2-3a04ba1e76ab --follow-tracks --view-size=12
```

`--view-size` sets only the starting orthographic view size. The wider Gallery
framing keeps the caster and distant area effects in view; wheel zoom remains
available and seeking retains the chosen zoom.

`tools/studio_gallery_spell_capture.py` regenerates a new run through the normal
SDK. Its explicit scenario setup grants the premade Sorcerer the Shield reaction;
all subsequent reactions and outcomes are server-owned.

### Capture a recorded sequence for visual review

`tools/review_studio_sequence.py` opens its own offline Studio process and captures
the actual UI plus clean world panes through the existing replay/readiness gates.
It never generates server outcomes or replaces the current user preview. Times
are seconds on the published Studio timeline; requested and published times,
source/event rows, faction, camera and rendering errors remain in each receipt.

```sh
# Existing Factory Python environment supplies Pillow; ffmpeg must be on PATH.
/home/tommaso/.cache/vfxfactory/export-venv/bin/python tools/review_studio_sequence.py \
  --godot /mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe \
  --factory /mnt/c/Users/tommaso/Documents/assets/VFXFactory \
  --spells fire_bolt magic_missile --perspective amber --camera 0 \
  --review-fps 12 --output .captures/studio-sequence-review/first-pass
```

Use a fresh output directory. `--spells all` selects every real recording in
`generated/studio_spell_case_inventory.json`, including their original journal
paths; a spell's further cases are named by their case suffix (`shield-ranged`,
`shield-walk`). Use `--recording res://.../amber/journal` for another existing SDK journal.
`--row <exact-row-id>` selects an authored occurrence's interval; `--start` and
`--end` bound a full-recording review. `--at 1.2` instead captures one settled
still and needs neither ffmpeg nor Pillow, so ordinary `python3` is sufficient.
`--godot` can also come from `GODOT`; `--factory` from `VFXFACTORY_ROOT`.

The runner imports the Factory's existing `package()` and `contact_moments()`;
it does not copy the packager or the Factory renderer. Each completed sequence
gets MP4, a contact sheet and `sequence.json`; stills keep their original PNGs.
The batch has `index.html`, `job.json`, `capture.json`, `runner.json` and both
console/Godot logs. Successful sequences retain selected contact frames by
default; `--retain-frames` keeps every UI/world image. Failed or incomplete
receipts keep their frames. The watcher stops only its own executable/job on
script error or `--timeout`; other Godot previews remain open.

The owned capture process runs at60Hz; review FPS controls screenshot sampling,
not the renderer's source clock. A
12-FPS clip can miss a brief hit flash: use a higher rate or an exact-time still
for that boundary. A finished capture is evidence to inspect, not artistic
approval or proof that every recorded presentation channel is implemented.

**Inspect → Follow active track** follows the newest active component lane,
opens its event ancestors and keeps the playhead in view. It follows the actual
published replay time. Sequence capture enables this and rejects a capture if
the selected lane is outside the published timeline viewport. Receipts include
the followed row, all active row IDs, scroll position and both faction clocks.

The first production qualification captured Fire Bolt (55 frames), Magic
Missile (36), Mage Armor (59) and Web (46) at12FPS. Web retains two independently
reduced panes at the same published time throughout. A requested-time rounding
error at Magic Missile's cast boundary was caught by the visibility assertion;
the observer now follows the published clock, just like Studio playback.
Evidence is under `.captures/studio-sequence-review/first-production` (Fire Bolt)
and `.captures/studio-sequence-review/production-final` (the other three).

The30 migrated spells select their native Factory phases through
`authoring/native_effects/index.json:/spells`. The real player and Studio use the
same compiled event components, native source sampler, placement and receiving
body material. Phase rows show actual source previews; their child rows expose
source-light keys and the actual damaged recipient's material interval.
**Inspect → Full spell hit material** switches between that material and Colour
treatment. The dedicated assembled-body thumbnail remains an explicit gap;
inspect the receiving actor in the replay for that channel.

The real Shield-blocked case can be opened with
`studio.cmd --recording=res://.runtime/studio-cases/magic_missile-seed3/amber/journal`.
Its missiles must not produce damage flashes. The migration's successful-hit,
seek/loop and native framebuffer checks use the other recorded cases listed in
[the migration plan](../agent_docs/NATIVE_SPELL_CLIENT_MIGRATION_PLAN_2026-10-15.md).
The complete batch is selectable under **Spell composition** and the capability
Library, with original recordings for both audiences in
`generated/studio_spell_case_inventory.json`. Native condition entry/hold/removal,
Shield interception, Web ownership, healing and area effects use the same player
components and are exposed on their owner tracks. Every spell's timing and
positioning still needs artist tuning.

Since 18 October each inventory case records the spell's whole lifecycle
(`.runtime/studio-spells-20261018/`): the cast and its impact, the lasting
condition on its recipient, the recipient walking with it on, the condition
ending through an ordinary engine rule (expiry by ended turns, dropped
concentration, donned armour, Shake Awake, the next turn start, damage spending
False Life's temporary hit points) and a walk of about two seconds afterwards.
Each case's `lifecycle` rows name those events by journal sequence and event,
with the published Studio time for both factions (`published_ms`) and the
event's own presentation rows. `ending` and `lifecycle_gaps` state the rule used
and what the engine cannot show (a sleeping, restrained or commanded recipient
cannot walk; Shield and Shocking Grasp end when the recipient's own turn starts;
Aid has no in-encounter end). Turns take no presentation time, so an expiry at a
turn boundary appears at the instant the preceding walk arrives. Aid, Bless,
False Life and Sacred Flame are recorded but have no native effect authoring yet
(`native_effects_authored: false`). Two further Shield cases show a shortbow
arrow turned by Shield (`native-spell-shield-ranged`) and Shield cast against an
opportunity attack, then held for the rest of the walk (`native-spell-shield-walk`).
Regenerate with the pinned engine copy:

```sh
E=/home/tommaso/.cache/ndclient/dnd_engine-229ce025f
cd tools && PYTHONPATH=$E:$E/sdk/python/src /home/tommaso/.cache/dnd-engine/venv/bin/python \
  studio_spell_lifecycle_capture.py --engine $E \
  --godot /mnt/c/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

`--godot` reads every lifecycle event back through the Studio's own
single-faction index and seeks to it (`tools/studio_spell_lifecycle_times.gd`).

Hide now has separate selected action and condition recipes. Open **Hide → Apply / move / attack →
Hide and subsequent attack** to inspect its real paired faction recording.
The actual modular source clips are `CrouchIdle` and `CrouchRun`: 15 frames,
explicitly authored at 12 FPS here. The source handoff had no adopted crouch
timing; 12 FPS is a new presentation choice. Hidden actors admitted to the
current faction's view use 0.55 opacity. Walking selects the crouched movement
clip; attack, hit, jump and death arbitration remain with their existing tracks.
The recorded state determines when Hidden ends. Other factions never gain a
character merely because a Hidden visual exists.

The action owns a 416.667 ms `CrouchIdle` playback at 3× speed. Its final source
frame boundary applies the recorded child Hidden condition and starts the
selected `hide_transition` sound. This is newly authored reuse: the installed
library has no dedicated standing-to-crouching entry clip. It must not be
described as a recovered smooth transition. The current cue is a temporary CC0
quiet swish; the Resource selects it independently of its audio file.

Studio shows 500 ms of the real initialized state before the first operation,
then 350 ms between rendered user operations so a new condition's idle pose can
be inspected. The shared Timeline honors these passive preview start times;
live playback and every original group-local commit remain unchanged. In this
recording, absolute times come from the current index: earlier recorded equipment
actions now play their authored body before Hide. Metadata events and lineages
inside an operation do not each receive a pause. Hide itself retains its
416.667 ms action-to-effect interval; the current recording places it at
1266.667–1683.333 ms, followed by the 350 ms Hidden idle inspection interval.

Edit the selected `.tres` in Godot, then use Studio **Reload**:

| Native source | Authored data |
| --- | --- |
| `authoring/presentation/catalog.tres` | Selected action/condition recipes and additional body clips |
| `authoring/abilities/actions/action.hide.tres` | Event-owned action clip, playback rate, effect frame and effect audio cue (abilities source) |
| `authoring/abilities/conditions/condition.hidden.tres` | Shared body look, idle/move pose selections and +/- text feedback (abilities source) |
| `authoring/presentation/clips/modular_crouch_idle.tres` | Existing CrouchIdle sheet registration and explicit source clock |
| `authoring/presentation/clips/modular_crouch_run.tres` | Existing CrouchRun sheet registration and explicit source clock |

The Resource scripts in `presentation/resources/` are passive typed data.
`source_catalog.gd` and `presentation/native_authoring.gd` validate and resolve
them into the existing compiler operands. Legacy JSON remains intact and supplies
unmigrated fields. An assigned native body filter replaces opacity and colour
operations, including explicitly neutral values. The inspector links the exact
effective Resource property and preserves the original JSON provenance.

The event path is shared by live play and Studio:

1. The SDK admits each subjective server packet and reduces authoritative state.
2. `presentation/compiler.gd` resolves recipes and produces causal groups,
   body tracks, components and state commits. Event diagnostics consume these
   selected recipes instead of independently selecting variants again.
3. `presentation/timeline.gd` owns display time and condition lifetimes. Shared
   selectors choose pose/material samples from those owners; they do not create
   a second event clock or change gameplay outcomes.
4. The existing character graphs, component renderer and shaders display those
   samples. Studio indexes the same tracks and samples their actual sources.

Condition `feedbackColor` describes a floating `+Hidden`/`−Hidden` badge, as in
the Pygame authoring; it is not a full-body hit flash. Badge lifetime is independent
of the semantic event join. Existing damage flashes still use their shared
material component.

Each admitted source revision supplies immutable effective documents to the
session, media workers and thumbnail jobs. Seeking reuses that revision. Reload
validates a separate candidate, restores the selected time, then publishes it
when ready. A missing or invalid Resource retains the previous world, clock and
authoring. Resources contain no mutable actor or playback state.

This native migration currently covers the modular Hide action, Hidden pose/filter/feedback,
their crouch sources, and shared contour indicators for Dodging and
Disengaging. The unrequested Dash contour was removed. Its original movement
media remain explicit unimplemented requirements. The remaining contours are
new passive visual choices in their original feedback palette; their legacy body-disabled actions remain unchanged. Other rigs require an authored crouch selection; magical
Invisibility is still separate work. Existing native VFX use the shared native
effect loader and their current source catalog; they have not all been converted
to these Resources. Missing effects and conditions remain in the worklist.

## Validation and remaining VFX work

Current evidence is in `generated/studio_authoring_audit_checks.json`,
`studio_inventory_native_checks.json`, `studio_perspective_checks.json`,
`studio_condition_navigation_checks.json`, and `condition_coverage_checks.json`.
The native worklist captures are under `.captures/studio/inventory/`.

The earlier 741-check report qualified the **Hidden condition**, not the missing
Hide action. It did not establish the requested idle → action → Hidden sequence.
The current action-transition native rerun passes **1139/0** with equipment
presentation enabled;
its result is in `generated/studio_hide_render_checks.json` and
`.captures/studio/hide-native/`: actual four-view CrouchIdle/CrouchRun, assembled
source previews, original gear/normal registration, alpha coverage, attack and
authoritative removal, unseen faction exclusion, reverse-seek pixel equality,
and rejected candidate retention. Continuous playback records 29 normal-idle,
60 action and 33 Hidden frames without a boundary violation. Hidden begins and
exactly one native cue crosses/plays at 1683.333 ms; the recorded audio mix is
nonzero. This supersedes the historical 500/916.667 ms absolute boundaries from
before preceding equipment playback was restored. The fixture uses Forward+ with unchanged game
lighting. The recorded room is dark; source thumbnails expose the pose without
changing its scene illumination. Headless source/order/reload evidence is in
`native_authoring_checks.json`, `condition_pose_checks.json`,
`studio_native_condition_checks.json`, `component_trace_checks.json` and
`studio_seek_native_authoring_checks.json` under `generated/`.

`studio_timing_checks.json` passes 117 checks on the actual paired recording:
unchanged full compiler groups, real initial state, action/effect ownership,
condition idle and movement, forward/seek and prepared publication parity.
`studio_seek_timing_checks.json` passes 1029 checks. The authoring audit passes
6516 checks, including native property provenance, inherited fields and action
aliases/shove source identities. These are semantic/source checks, not pixel or
audio acceptance.

Blood follows the disclosed `body_release` identity and actual receiving regions;
physical damage alone does not create it. Ground-capable releases use the existing
Pygame particle/kernel artwork, native batched geometry and the approved native
2D receiving lights. Each landed increment reveals only its exact authoritative
tile residue after-value, preserves an older stain and survives the finite spray.
An airborne release with no regions remains air-only, including lethal injuries.
The earlier removal of the manufactured Hide deposit reduced its tail from
2750 ms to 150 ms; that final feedback tail remains. No blanket truncation was
added.

`blood_residue_checks.json` passes 281 source/authority checks and
`blood_authority_checks.json` passes 69 boundary checks. The native actual Dash
opportunity-hit fixture passes 67 checks: continuous no-blood → spray → twenty
retained tile surfaces, partial landing, four camera views, exact reverse field
bytes, a red/transparent source thumbnail, and preparation cancellation. Its
81,920 field samples agree with the independent original Pygame float32 formula
within 0.004704 in native RGBA16F storage; this is numeric field comparison, not
an assertion of final framebuffer byte equality. Captures are in
`.captures/studio/blood-residue/` and results in
`generated/studio_blood_residue_checks.json`.

On the measured twenty-tile occurrence, warm transient blood CPU cost was
1.195 ms median / 7.213 ms p95 / 7.772 ms maximum; settled cost was
0.173 / 0.228 / 0.228 ms, with no settled field uploads. The existing preparation
owner allocates at most two hidden tile fields per frame before admission.
Preparation measured 0.359 ms median with a separate 15.666 ms cold native
page/material setup. This removes the previous twenty-surface allocation at
contact; it does not establish a strict frame budget. Known stain culling still
scales with retained residue tiles. Elemental/frozen blood variants and arbitrary
scenery crossings are outside this finite physical-blood qualification.

Lighting uses the existing native PointLight2D path, calibrated to admitted source
radii, intensity and colour. Schema-9 optical source observations include unseen
emitters without exposing hidden actor/item identities. There is no new per-cell
field renderer or gameplay lighting solver. Server-owned Hidden/visibility
outcomes remain authoritative; brightness does not universally remove Hidden.

Historical evidence for the three basic contour indicators was 201 recorded
checks and 153 native checks. Dash has since been unassigned; these counts do
not qualify its current presentation. Those historical checks covered: actual UUID lifetimes, unchanged commits/body tracks/durations,
four camera views, exact mute restoration, removal and reverse seek. Reports are
`generated/basic_condition_checks.json` and `basic_condition_render_checks.json`.
Equipment presentation passes 189 recorded checks: the original modular Taunt
at 3× speed publishes equipment at source frame 4, preserves every canonical
after-value and event order, and restores the same prefix on reverse seek.
The equipment context and rig overrides remain the authoring authority.
Frenzy uses the already installed original ground mechanism with its original
red palette and recipe timing; 11 source checks and 50 native checks cover its
actual occurrence, four views, exact mute restoration and lifetime boundaries.
Reports are `equipment_presentation_checks.json`, `frenzy_presentation_checks.json`
and `frenzy_render_checks.json` under `generated/`.
This does not establish completion of every base-case scene; blood, damage/life
timing and expanded licensed audio have the separate finite acceptance below
and above. Unselected spell/condition mechanisms, remaining native assignments,
and deferred Gallery performance work remain
separately visible; source availability is not a rendering qualification.

The combat timing suite passes 1750 semantic checks across damage, dying, lethal
opportunity attack and revival. The actual dying recording also passes 35 native
Studio checks: one fall into Dying, authoritative death-save/Dead commits, the
retained witnessed corpse and terminal Die source pose, reverse seek and 571
continuous frames. Audio uses authored components and native Godot players in both production and
Studio. Exact-onset Play starts a one-shot once; seeking inside a past one-shot
stays silent; pause/resume retains its voice. The listener follows the isometric
focus, independently of camera height. Voices honor authored attachments, buses,
gain and loop offsets. Source waveforms repeat on the same source clock as the
player. Inspect an audio row for source readiness, scheduled/native-started state,
or a concrete skipped reason; a waveform alone is not playback evidence.

Sound assignment and timing are editable in `authoring/audio/`; its `README.md`
is the artist handoff. Run/CrouchRun footsteps use source-frame contacts. Jump
keeps its actual ground endpoint; the selected landing source begins80ms earlier
so its impact coincides with touchdown. Studio marks contact separately from
waveform onset. Unreviewed creature/window contacts remain explicit authoring gaps.

Offline comparisons retain separate SDK state, Timeline, World3D, materials,
lights and audio presenters. Shared event/lineage IDs align the views; packet
sequence numbers do not. Every due commit at a common cut is prepared before
either pane publishes. Seeking and looping prepare both worlds privately; one
slow pane holds the common clock. Private candidates and the unselected listening
faction are silent, including nonspatial audio. `--single-view` retains the
single-view diagnostic path. No live Session or multiplayer feature was added.

Validation reports are `generated/studio_audio_transport_checks.json` (actual
Move, Jump, melee and Hide/light PCM and emitted IDs),
`generated/studio_replay_comparison_checks.json` (causal alignment),
`generated/studio_replay_prefix_checks.json` (incremental exact own prefixes), and
`generated/studio_replay_native_checks.json` (two native panes, Hide/light reveal,
Invisibility, lethal opportunity attack, seeking, looping, delayed preparation,
cancellation and rotation). Native PCM proves mixer output, not loudspeakers or
a professionally finished mix. Existing live world-preparation and viewport
layout regressions also pass. The replay work preserves the approved lighting.

The reproducible `tools/studio_base_capability_audit.gd` compiles all 29 registered
real cases and records event-owned bodies plus remaining expected-component
gaps in `generated/studio_base_capability_audit.json`. The earlier core-case zero-missing result was incomplete: the denominator omitted
conditional movement effects and did not expose every rendering operation.
It is not completion evidence. The current work expands the required-presentation
inventory independently of successful rendering; studies and their missing work
remain visible before any new visual model is implemented. The larger movement/OA scenario
still names its Haste-potion release, while the spell probes retain explicit
Shield, Mirror Image, See Invisibility and Concentrating gaps. Their exact source
pointers remain in Studio's worklist; they are not hidden by the base-case result.
