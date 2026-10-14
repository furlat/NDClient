# Godot Studio — first chunk: base mechanics, layers, conditions and sound

Date: 13 October 2026. Updated 14 October: Studio workspace, real-recording transport and source-derived worklist are implemented. Renderer coverage remains partial; the current requirements and remaining gaps are recorded below. Historical validation counts qualify only their stated cases.

## 1. Outcome and authority

Deliver a usable Godot Studio that opens real server recordings, renders the actual game, and exposes the complete resolved presentation on an Adobe-like timeline. The initial workspace is approximately half rendered preview above and half tracks below, separated by a draggable horizontal divider. Tracks contain actual sampled sprite/native-effect previews, nested dependent components and sound waveforms. The timeline is read-only; canonical JSON can be edited externally and explicitly reloaded.

Recover the existing TS/Pygame presentation choices first: body/equipment composition, hand magic, weapon glow, aura/effect/slash layers, spell material coloring, sockets, source clocks, conditions and causal timing. Adopt the corresponding native Godot VFX that generated exported sheets. Improve blood and damage-material flashes immediately. Introduce sound in this chunk. After this base is qualified, implement spells by level through the same machinery.

This plan incorporates the user's current instructions and narrows the first delivery of the [recovered master, section 8](post_mortem/NDCLIENT_IMPLEMENTATION_PLAN_COMPLETE_2026-10-11_v3.md#8-studio-read-only-inspection-of-the-production-runtime). The [Godot Studio review](GODOT_STUDIO_REVIEW_AND_DESIGN_2026-10-13.md) supplies findings to reproduce, not proof that those findings are already fixed. Current user instructions supersede older restrictions on native VFX or new sound authoring. No gameplay implementation, asset import, server run or preview restart is authorized merely by writing this plan.

### First-chunk completion means

- A launched native Studio with the specified layout and a finite, real-server base-mechanics recording set.
- The same SDK reduction, resolved authoring, causal compilation, displayed-state commits, sampling and rendering used by live play.
- Actual thumbnails and dependent subtracks; pause, forward/backward seek, source-sample stepping, rate control, loops and four camera views.
- Recovered body/equipment/effect layers; native base-action VFX; directional impact/blood and material flashes; condition lifecycle support; audible initial sound cues.
- Per-component visual/audio coverage, including explicit missing implementation, missing source and unexercised cases.
- Native visual and listening evidence, behavior checks, and measured responsiveness at the existing large-map scale.

Do not present a timeline shell, a cast gesture alone, a static atlas, or a JSON dump as completion. Do not claim the entire spell/condition catalog is implemented because this first chunk passes.

## 2. Scope and recorded cases

Use the current engine's legal actions and outcomes. The capture driver selects setup, actors and commands; it does not manufacture success, damage, reactions, condition changes, death or visibility. Existing valid captures can be reused. Missing cases are recaptured through the current server/SDK.

| Case family | Required first-chunk observations | Visual/audio components and causality to expose |
| --- | --- | --- |
| Ordinary movement | Cardinal/diagonal routes, stop/start, elevation and an authored connector; movement with an active condition | Body/equipment pose, attachments, footsteps, support height and commits |
| Jump | Takeoff, airborne interval, landing; movement interrupted by opportunity attack, including lethal interruption | Authored arc and source frames; held/reaction intervals; permitted landing/termination effects and audio |
| Window traversal / jump through a window | Existing cleared aperture crossing from both sides using the engine's actual jump/connector semantics; blocked aperture refusal; break/clear followed by crossing where supported by normal setup | Window insert/frame ownership, actual clearance timing, passage body registration/pose, sound and actor traversal; not a generic jump drawn through an intact obstacle |
| Weapon combat | Melee and ranged hit/miss, critical, damage, death, attack of opportunity | Windup/contact/recovery, weapon/effect layers, delivery, material flash, blood, numbers and ordered consequences |
| Shove/forced movement | Push success/refusal, prone and stand-up; interaction with support/obstruction | Attacker's authored Kick/contact; target brace/displacement or fall; impact/ground effects; source-relative direction |
| Basic actions | Dodge, Dash, Disengage and Hide followed by actions that exercise their effects and expiry | Correct application/sustain/removal, authored accents and indicators; no invented body animation for an authored body-disabled action |
| Action economy | Attack + Extra Attack + Action Surge + subsequent legal attacks, plus exhausted/unavailable action | Separate authoritative occurrences, unchanged costs/turn state, authored Action Surge VFX/audio, no visual restart or duplicate consequence |
| Conditions | Base-action conditions plus poisoned, paralyzed/prone, Rage or another existing persistent material, and an authored attached effect | Apply/sustain/remove; already-active initialization; source ownership; suppression/restoration; overlap with damage flash and movement |
| Composition probe | One existing Magic Missile recording, preferably A → B → A, and one existing persistent-condition recording | Recover hand magic and spell materials; release before gesture end; distinct repeated recipients; native phase composition. These are framework probes, not a claim of level-one spell completion |
| Combined regression | Current furnished Gallery recording with elevation, actors, scenery, movement/reactions and a destructible passage | Full production composition at scale, four views, wall modes and existing approved lights; no simplified Studio-only world |

Reuse the existing map; this chunk does not commission another giant map. Small setup cases isolate mechanics while the Gallery proves combined behavior. Window destruction remains its existing authored source unless a selected native counterpart exists; native VFX adoption does not require converting environment or character sprites into meshes.

Old scenarios under dnd_engine/game_obsolete are semantic references, not current server captures or import targets. Current window behavior is also exercised in dnd_engine/tests/engine/test_windows.py and test_window_attack_access.py. If current public setup cannot express a required case, identify that exact setup gap; do not inject private events or quietly drop the case.

### Condition coverage boundary

Enumerate every existing condition recipe/indicator in the first chunk (currently 160 recipe entries, including class and spell states; this is not 160 distinct visual mechanisms). Preserve all existing assignments and expose their expected components and source locations. Recover existing indicators through the shared layer/material/native-effect mechanisms wherever applicable. An empty or optional old recipe must not make an absent required indicator silently pass.

The first-chunk behavioral suite deeply exercises the lifecycle and composition mechanisms above. Spell-specific condition applications, unusual transformations and interactions are then qualified with their spell levels. Each unexercised or unsupported catalog entry remains visibly incomplete. This separation cannot be used to omit a condition needed by a required base case.

## 3. Workspace and use of space

Use normal Godot Control/Container nodes for layout, focus, buttons and scrolling, with a custom clipped timeline Control for time geometry, thumbnail strips and markers. Use a vertical SplitContainer for the draggable preview/timeline boundary; this is a native [Godot layout capability](https://docs.godotengine.org/en/stable/classes/class_splitcontainer.html).

Initial proportions apply to usable content after the compact header, not half the screen lost to toolbars. Start at 50/50; retain the user's divider position locally. Keep a usable minimum for both panes and support preview-maximize/timeline-restore. Resize must not restart playback, rebuild the world, discard prepared thumbnails or move the playhead.

~~~text
┌──────────────────────────────────────────────────────────────────────┐
│ Case / search     Reload authoring     View     Inspector Log Coverage │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                  ACTUAL PRODUCTION GAME PREVIEW                       │
│          equipped actors, map, lights, conditions and native VFX       │
│                                                                      │
├════════════════════ draggable divider ════════════════════════════════┤
│ Play/Pause  Step  Speed  Time  Loop    Fit / Zoom     Track filter      │
├───────────────────────┬──────────────────────────────────────────────┤
│ Track / owner         │ seconds ruler + release/contact/commit marks   │
│ ▾ Attack occurrence   │                 │playhead                     │
│   Body composite      │ [actual pose][actual pose][actual pose]        │
│   ▸ Body/gear parts   │                …                              │
│   Hand magic          │ [material-colored effect samples]             │
│   ▾ Impact on target  │                    [native impact samples]    │
│     Material flash    │                    [affected actor samples]   │
│     Blood             │                    [spray] → [deposit]        │
│     Contact sound     │                    ≋ actual waveform ≋        │
│ ▾ Active conditions   │ [application] [sustain ................] [end] │
└───────────────────────┴──────────────────────────────────────────────┘
~~~

The sketch illustrates hierarchy, not a fixed schedule. Its times come from recorded causes and authoring.

### Layout rules

- Preview fills its pane. Case/library browser, source inspector, combat log and event/coverage views open on demand as closable overlays/drawers. No permanent wide right column or redundant full-height panels.
- One compact workspace header and one transport row. Start label gutter near 240 logical pixels and make it resizable. Keep the ruler and labels pinned while clips scroll horizontally; labels and lanes share vertical scrolling.
- Use compact parent/metadata rows and larger preview rows. Start around 28 logical pixels for group rows and 64–80 for visual rows, adapting to UI scale. These are layout starting values, not hard-coded source-cell dimensions.
- Show the composed Body at normal thumbnail size by default. Physical body/gear parts are a separately collapsed group. Hand magic, aura, material operations and action effects remain discoverable without expanding every clothing part.
- Expand meaningful effects for the selected occurrence; collapse unrelated occurrences. Provide expand/collapse controls, search and filters for actor, component family, missing status and condition. Filtering never changes the executable schedule.
- Do not render a full-screen widget tree for every frame or source component. Draw visible rows and time intervals with a small scroll margin. Keep row identity stable across expand/filter/view changes.
- Inspectors identify owner, cause, source file/JSON pointer, selected variant, authored value, resolved value, units and missing capability. Keep technical detail here rather than cluttering the preview.
- Missing imagery is a labeled placeholder, never a generic colored bar presented as a valid preview. Status uses text/icons as well as color.

### Interaction

Preview owns its camera gestures: pan/zoom and Q/E four-view rotation when preview focus is active. Timeline owns scroll, zoom around the cursor, selection, playhead/loop dragging and keyboard stepping. Space toggles playback in Studio; it cannot end a game turn. Text fields and modal controls consume their input. Escape closes the most local overlay. Studio does not expose live gameplay commands.

Show source-frame/sample time and resolved milliseconds when selecting a thumbnail or marker. Step according to the selected lane's real sample boundaries; for continuous native effects use that recipe's declared simulation/sample interval. There is no universal fake 30 FPS editor clock. Track edges and authored markers are inspection-only; no drag editing of gameplay or authoring values in this chunk.

## 4. Shared execution and ownership

~~~text
real server → current SDK → exact authorized initialization/operations
                                  ↓ recorded case on disk
live intake ──────────────────────┐
recorded intake ──────────────────┴→ same reducer → resolved authoring
   → same causal compiler → displayed commits + retained components
   → same sampler → production rendering and audio
                       ↘ Studio rows / inspector / coverage / thumbnails
~~~

| Existing owner | Responsibility in this chunk |
| --- | --- |
| sdk/journal.gd, sdk/reducer.gd, SDK transport | Admission, protocol, authoritative state and saved operations. No Studio rules or event fabrication |
| presentation/session.gd | Existing live/recorded input and preparation handoff. Keep bounded live lookahead; full offline indexing is separate retained data |
| presentation/authoring.gd and current catalogs | Resolve an occurrence's complete authored composition once, including variants, layers, materials, native sources and audio |
| presentation/compiler.gd and tracks.gd | Compile actual causal dependencies into sampled components and state commits; keep the current compile_recorded single-reduction handoff |
| presentation/timeline.gd | Display time, commit progression and retained lifetimes. Restore the same sampled state on seek |
| Production character/world/native presentation owners | Own drawing and effect/audio handles. Godot nodes do not become authoritative entities |
| presentation/event_trace.gd | Consume the same resolved requirements and actual witnesses; do not resolve recipes independently |
| New Studio scene and small UI files | Layout, transport commands, read-only projections, selection, inspector and bounded preview demand |

Refactor only the production host seams required to mount its world in the Studio preview and accept recorded input. Do not fork play.gd/main.gd into a parallel renderer. The exact Studio filenames can follow the repository's existing organization; a speculative class hierarchy is not part of this plan.

Keep authoritative state and compiled presentation as passive data, transformed by functions. Use finite component handlers for actual mechanisms (body/layer samples, motion, material operation, native effect, deposit, audio), not a universal plugin/graph framework or one scheduler/class per spell. Godot nodes are appropriate resource and presentation handles. Existing actor body arbitration must remain distinct from parallel effect/material tracks; the current one-winning-body-track-per-actor behavior cannot erase attached components.

### Resolved component information

Extend current compiled records with the information needed by actual consumers: stable occurrence/component and parent identities; actor/object/condition-source owner; source event and cause; selected source file/field and recipe; source clip/phase/material/scene; local-to-display time mapping; attachments/endpoints/direction; start/sustain/end and interruption policy; release/contact/commit dependencies; required resources and implementation status. Audio adds its clip/cue, marker or interval, spatial attachment and mix settings.

The same records drive drawing, requirements, inspector values and timeline rows. Do not create a parallel manually maintained track catalog or duplicate every source field into a new schema. Add native/audio source variants only where the current authoring representation actually changes, and validate those fields once at the source boundary.

## 5. Recording, time and replay

Capture exact current SDK initialization and ordered operations, their authorized audience/content, and enough complete prefix to resolve the selected interval. Keep event identities, operation positions and ancestry intact. A small local case descriptor carries label/tags, interval and the selected authoring baseline. No new signing/provenance server, scenario language or registry service is required. Keep credentials and private server setup outside shareable cases.

Use tools/presentation_scenarios.py and tools/gallery_recording.py as working capture paths; reuse existing server setup and command discovery. Keep capture outside Studio. Studio must open its saved case with the server stopped and perform no bootstrap, choices, preview, content-fetch or command request.

Build the complete recording's semantic track index before playback can claim the case is ready. Indexing can progress asynchronously with a visible status and cancellation. This does not load every historical texture or native instance onto the GPU, and does not enlarge the live session's bounded queue.

Build that index from the same compiled records, not the bounded event-log/trace history and not by disabling live lookahead limits. Offline Studio deliberately exposes the entire selected audience recording in its tracks before Play. Its preview, HUD and combat log still follow the displayed commit; full track inspection grants no access to unrecorded objective state.

Semantic rows retain the occurrence/source/timing references they need. They must not accidentally keep a duplicate complete world state or native GPU instance per row. Finite immutable execution records can be retained where useful; choose replay/checkpoint retention from measured costs rather than adding a new storage framework.

Keep displayed time separate from received/reduced position. Authoritative consequences commit at the existing causal presentation boundaries. Attack, damage and death/log entries retain their actual hierarchy and dependency order even when some effects overlap. Repeated recipients produce distinct occurrences. Existing native resource spending/Extra Attack/Action Surge legality stays server-owned.

Recover aggregate/action scheduling as well as leaf attacks: an authored Action Surge effect must run at its markers, while a body-disabled multiattack wrapper schedules its actual recorded children without adding an invented body clip. Historical previewChildCueKinds metadata describes expected child kinds; it cannot manufacture those occurrences or their order.

Backward seek restores state through the commit schedule at the requested time plus active presentation lifetimes, then samples that time. Do not expose a whole operation's final state early. Initialization/prefix replay is the correctness reference; add checkpoints only where measured replay cost warrants them. Retain scene, log, visibility, equipment and conditions consistently. Seeking never reruns a command or rerolls an outcome.

Body/property animation follows the shared clock. Godot documents that AnimationPlayer.seek skips intervening events and does not emit completion at the end; semantic commits therefore cannot depend on animation_finished. Use property sampling with method/audio side effects suppressed where supported, and explicitly schedule sound separately. See [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html).

Native particles require simulation history, not merely a time assignment. Reuse Factory's declared clocks/seeds and simulate moving emitter transforms, emission intervals and trails in bounded private preparation. Pause automatic advancement when explicitly stepping. A forward simulation request adds time; it is not an absolute seek. On backward seek, rebuild the relevant occurrence history and atomically install the ready sample. Fixed seed plus age alone is insufficient for world-space moving trails. Test repeatability on the installed renderer; do not promise cross-GPU identity. See [GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html).

Existing workers prepare passive records and resource demands. Native node/material creation, GPU simulation requests and rendering remain with the scene/render owner in bounded batches; asynchronous preparation does not mean running the active SceneTree or particle rendering on compiler workers. Use each source's explicit clock bindings, not a blanket rewrite of every TIME/autoplay occurrence.

All visual time—including persistent conditions, shader uniforms and relevant world animation—pauses with displayed time. Tag seek/reload/case/camera preparation by generation so stale work cannot install its scene or thumbnails. While a replacement sample prepares, retain the last coherent display with an explicit preparing state; do not show new HP against an old world or claim the requested frame is ready.

At the recording's final semantic commit, ambient/idle animation and genuinely persistent effects can continue on the same displayed clock until Pause. The UI identifies the end of recorded events; it does not loop expired transient effects. Scrubbing or source-step pauses at the selected time. Do not add independent wall clocks just to keep the terminal scene alive.

## 6. Recover layers and migrate native effects

### Preserve existing composition

Body action is the pose clock. Body parts, equipment overrides and authored actor-effect slots sample its actual clip, source frame, direction and rate. Weapon replacement/visibility is distinct from weapon glow. Recover hand sockets and null/absent per-frame sockets; null attachment intervals do not render an effect at an invented origin. Release may occur while the cast gesture continues.

Spell/effect materials apply to the authored Magic/Effect layers. Preserve ordinary character/equipment tint and the approved normal-lighting path. A condition or hit material modifies only its declared recipient/mask and composes with the other active material operations. Temporary flash expiry restores the still-active underlying conditions and base appearance; it must not reset them.

Recover the existing source assignments from current authoring and TS/Pygame references, including rig-specific layers/accents. Do not replace assembled characters with a demo goblin or normalize creature sizes to a common height. Use the exact authored source/pivot/scale.

### Native VFX adoption

The native library is broader than the exported spritesheet selection. Current selected identities map back to their actual Factory implementations; additional library entries remain browseable and explicitly unassigned until authoring selects them. Source availability and production integration status are distinct. Use the [13 October source audit](/mnt/c/Users/tommaso/Documents/assets/VFXFactory/research/lelu-channel-2026-10-13/source-audit/INDEX.md); do not infer a scene from a similar filename. Enumerate the broader library without eagerly importing/compiling/rendering every original archive. Asset preview support is qualified on demand and exposes unsupported source mechanisms explicitly; a full library migration is not a prerequisite for the finite base-case delivery.

Reuse Factory recipe/component constructors, explicit sample/shader/AnimationPlayer bindings and material isolation. Preserve the complete effect: secondary layers, masks, gradients, particle curves, phase sequencing and native geometry. Do not import the donor demo camera, level, gameplay scripts, autoplay destruction or global WorldEnvironment. Keep source assets under the existing Git-ignored media policy, copy/adopt only the needed dependency closure, and keep current original sources intact. No re-export to spritesheets is required for runtime VFX.

Resolve semantic placement from recorded world positions, authored sockets/support and trajectory. Convert the source's calibration into existing client units deliberately. Preserve heading independent of camera view. Native back/front exports describe one original composition: instantiate that native composition once, rather than duplicating near/far copies and doubling particles or audio.

Retain the Factory's authored pixel/CIE palette operation at the intended effect/composition boundary. Do not recolor the entire game, replace original alpha with brightness, or introduce a global output clamp. Keep approved 2D+normal receiving lights in the 3D world. Any adopted effect light uses an explicit compatible authored path; a donor OmniLight3D cannot silently relight the world.

**Early integration gate:** current painted surfaces use painter ordering and depth-disabled presentation. Native effects that rely on depth textures, proximity fade, decals, refraction or particle collision cannot assume those sprites are ordinary depth-writing meshes. Qualify one real layered base effect and one impact/deposit in the actual renderer at four cameras, behind/in front of actors/scenery and on elevated support. Reuse existing authored masks/support/depth where the source requires integration. Choose the smallest shared rendering adaptation demonstrated by those cases; do not rewrite the approved renderer or substitute a flat approximation for a missing source capability. Any unresolved mechanism stays explicit in coverage.

### Immediate impact upgrade

Treat body reaction, attack/spell material flash, blood emission, deposit, damage feedback and death as separately inspectable children of the actual impact/damage occurrence. Keep their authored overlap and causal commits; they are not independent gameplay events invented by the client.

The flash samples the selected damage/spell material on the victim's current assembled silhouette/affected layers, preserving animation and alpha. Native blood uses explicit authored response selection and direction from the admitted impact/trajectory, with an authored neutral policy when direction is undisclosed. Support at least two contrasting impact responses and compare them in a moving equipped actor case. Do not emit blood simply because an attack was attempted. Airborne spray and lasting deposit have separate lifetimes; cosmetic deposits never create backend terrain or collision. Recorded world surface changes remain authoritative and separately owned.

Material operations are occurrence-local inputs, never mutation of shared source textures/materials. The existing capped-light path evaluates source color in receiving and final output; use one shared material interpretation and ensure each visual operation is applied once. Qualify cap on/off and Normals mode so a flash cannot reintroduce double tint, dark dots, altered base colors or receiving-normal changes.

Do not assume a source Decal, depth-reading plane and sprite deposit are interchangeable. Preserve the selected source's mechanism and qualify its receiver/placement in the hybrid renderer.

## 7. Conditions as retained presentation

Condition presentation is indexed by the recorded owner/source identity as well as recipient and recipe. One source being removed must not erase another surviving contribution. Reapplying/refreshing only replays entry if the recorded lifecycle and authoring require it. Initialization establishes existing sustain state without inventing an application burst or application sound.

Required tracks are application, sustained indicators/materials/pose/equipment changes, suppression intervals, restoration and removal. Existing head markers keep their own authored grouping/priority/cycling; that cycling must not rotate body/ground effects. Overlapping indicators remain legible and follow authored head/ground/body anchors across poses and four views.

Exercise sustain while walking, jumping, attacking and taking damage; source removal and expiry; multiple sources; suppression; death/life-state eligibility; and backward seek across these boundaries. Removing a hit flash must reveal the current condition material, not a cached pre-condition body. Diagnostic mute/solo hides presentation only; it never removes a condition or changes HP, legal actions, event ancestry or commits.

## 8. Sound in the first chunk

Audio is a new authored presentation component in the same event timeline. Implement it with native Godot audio players and buses, not a second action scheduler. Use spatial attachment for world cues and nonspatial playback for actual UI cues. Godot provides spatial playback, seeking and stream pause controls in [AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html).

Initial cue inventory: footsteps by available surface/gear distinction; jump takeoff/landing; weapon swing/projectile release; physical impact; damage reaction where an appropriate source exists; window break/traversal; Action Surge; condition apply/loop/remove; the probe effect's release/impact. A missing optional layer is visible, not synthesized by an arbitrary beep or a secretly reused unrelated clip.

Authoring records cue/clip selection, source marker or interval, attachment, gain, bus, selected variation, loop points and release/fade behavior. Keep repeatable variation choice per occurrence for replay. Introduce modest simultaneous-voice limits and gain control so repeated hits or sustain loops do not become uncontrolled overlap. Limits and fades cannot alter event scheduling.

One-shots play once when forward playback crosses their marker. Seeking, thumbnail sampling, inspector selection and source reload do not replay historical one-shots. Sustained loops restore the active interval and offset, pause/resume with display time, and stop/fade on actual removal. Explicit loop playback can replay shots on each forward pass. Initially, each voice's playback rate follows Studio speed, with the resulting pitch change labeled; pitch-preserving time stretching is not a first-chunk requirement. Do not alter global audio speed for other consumers or accumulate sound lag behind slowed visuals. Silent scrub is the default; deliberate audition is separate. Disable donor autoplay/method-track audio that would duplicate these owned cues.

The inspected namespaced Factory library currently has audio-player nodes but no standalone WAV/OGG/MP3/FLAC bank. Establish a small real temporary sound set for this chunk, with source/license information and an obvious temporary status. Audible initial coverage must include footsteps/landing, attack/contact, one ability cue and one loop lifecycle. Missing remaining cues are reported individually; professional polish is not falsely claimed. Asset selection/research can be handled by a separately requested sound task; this plan does not create or message another chat, purchase assets, or contact anyone.

Give a future sound designer actual recordings, cue timing, loop/exit needs, variants and the current mix. Replacing a clip should not change event logic. Studio shows cached waveforms for real clips and labeled missing-clip lanes for absent ones. Audio and visual coverage are separately visible.

## 9. Timeline previews, preparation and reload

Rows are derived from compiled occurrences, not from instantiated GPU objects. Preserve causal parentage and dependencies: action → body/effect layers; impact → target reaction/material/blood/audio; condition owner → lifecycle. Cross-owner consequences retain their true owner even when nested under their cause. Link an already-existing condition track instead of duplicating its executable lifetime under each action.

Sprite thumbnails use the actual resolved clip/facing/frame, registration, palette and material. Show the full composed character on the Body row; expanded parts show their actual contribution. Native VFX thumbnails are samples of the actual native composition at relevant local ages, including context where the effect is only meaningful on an actor/ground. Material-operation thumbnails show the affected assembled actor. Labels distinguish source samples/frames from the number of thumbnails displayed.

Use shared resource handles and a bounded thumbnail viewport/atlas with separate mutable instances/materials. Never reparent the live actor/effect or read the full framebuffer back every frame to make strips. Prepare visible rows/time ranges first, cache results, evict offscreen demand within the existing memory policy, and cancel stale generations. Thumbnail simulations are silent. Shared immutable resources are reference-counted; closing Studio cannot destroy another consumer's resources.

Playhead movement only updates the playhead and sampled scene; it does not regenerate a strip. Time zoom changes sampling density incrementally. Vertical scroll, resize, expansion and camera changes preserve time, selection, semantic row IDs and useful cache entries; invalidate only view/source/material-dependent images. Give active scene preparation priority over thumbnail work.

External JSON reload goes through the same authoring resolver/compiler. Display the selected baseline and explicitly selected candidate. Recompile presentation against the same recorded outcomes, restore the chosen time and publish atomically when ready. Invalid source identifies its file/field and retains the previous usable case. Parameter edits do not trigger a full artwork reimport, SDK regeneration or new server capture. No draft manager, save endpoint or authoring editor is included.

## 10. Implementation slices and observable gates

These are internal work slices. Do not stop the implementation turn at a UI scaffold and describe the chunk as delivered.

| Slice | Work | Observable exit gate |
| --- | --- | --- |
| A. Baseline and case inventory | Record current source/baseline and existing valid captures; enumerate base-case expectations, all condition entries and their source requirements; use current paths rather than archived imports | Every required case has an input/capture route and explicit expected visible behavior; missing setup/source requirements are named |
| B. Resolve once and truthful coverage | Extend actual authoring resolution to all selected components; compiler and trace use that output; remove body-only false-green and unknown-as-neutral behavior | A missing Dash/effect/material component is red even when its body renders; state-only behavior has an explicit reason; existing movement/OA/order checks remain valid |
| C. First complete vertical example | Build the native split workspace, production preview, hierarchical track view and real thumbnails around an existing attack/movement recording; qualify one native action effect, impact material/blood and audio cue in the production renderer | Human can inspect a real composed event, pause, seek and see its actual nested components; four-view/source appearance evidence, no standalone simplified effect demo |
| D. Retained time and lifecycle | Finish full semantic indexing, absolute sampling/commit restoration, particle history, conditions and audio interval ownership | Forward/reverse seeking and loops restore scene/log/condition state correctly; no repeated shots/HP changes or stale scene installations |
| E. Base-case recovery | Complete the matrix in section 2, including window and Action Surge/Extra Attack sequences, all required effect slots, native counterparts and first sound set | Each required component is supported/prepared/sampled or the chunk is explicitly incomplete; expected authored source selection and baseline game visuals preserved |
| F. Workspace polish and reload | Density, thumbnail quality, inspectors, filters, all controls, input isolation, source reload and copyable reports | Usable at 1280×720 and 1920×1080 at normal UI scale; half split, resized panes, long tracks and deep hierarchy remain readable and responsive |
| G. Integrated acceptance | Review native playback, live commands, conditions/audio, source coverage, large-map measurements and independent review findings | Evidence table complete; required gaps resolved; no unsupported whole-catalog completion claim |

Do not postpone clock/composition qualification until after building hundreds of content entries. Do not expand the first chunk into all spell levels, an editable node graph, map editor, multiplayer rollback or another renderer optimization campaign. Fix regressions introduced by this work and measure its costs. Later spell-level work reuses these same capabilities and adds a shared mechanism only when actual content requires one.

## 11. Validation, profiling and reviewers

Follow dnd_engine/HOW_TO_TEST.MD: observable input → result checks, not private helper/class layout tests. Existing checks are references, not a mandatory rerun-everything ritual. No tests are run merely to write this plan.

| Boundary | Evidence required before declaring the chunk complete |
| --- | --- |
| Server recording → reducer/display | Real current-server prefixes, server stopped during Studio replay, unchanged ordered identities/outcomes; matching reducer and displayed commits at the selected time |
| Production ↔ Studio | Same recording/time/settings gives the same world/body/effect/material state and equivalent native output; hiding timeline does not change behavior; actual source/phase/material verified, not only actor position |
| Transport/seek | Start, release/contact ± one source sample, reaction/death, loop wrap, pause, slow/fast play and backward seek; moving native trails and existing conditions included |
| Layer and native composition | Equipped modular actors plus an authored creature accent; magic-on-hands and effect material; four views, near/far scenery and raised support; baseline tint/normals/light/wall appearance unchanged outside new effects |
| Base mechanics | The section 2 matrix, including real legal Extra Attack/Action Surge commands and window traversal/clearance; no scripted fake costs or outcomes |
| Conditions | Apply, sustain, expire/remove, already-active load, multiple owners, suppression/restoration, pose changes and flash overlap; all catalog gaps remain discoverable |
| Audio | Listen to real cues in the preview; correct contact, pause, loop exit and attachment; waveform corresponds to the clip; scrubbing/reload/thumbnail generation produces no historical sound burst |
| UI | Native screenshots at both target sizes, resized divider and expanded effects; actual previews readable; scrolling/typing/selection cannot issue game commands or move the wrong pane |
| Reload and teardown | Valid source change at same recorded outcome/time; invalid candidate retains previous display; case/view changes during prep reject stale results; no leaked emitters/audio/resources after repeated open/close |
| Honest coverage | Missing visual/audio requirement stays missing; supported is distinct from prepared/sampled, unexercised and offscreen/undisclosed; source consumption and behavioral evidence both reported |

Use the existing profiling system and JSON output. Separate replay index/reduction/compile, seek restoration, source preparation/upload, native simulation, thumbnail work, UI work and rendering/audio costs. Compare the same current Gallery recording and actual client-issued movement/attack sequence before/after; include cold/warm effect activation and a zoomed-out scene. Report frame-time p50/p95/p99/max, long-frame cause, readiness latency and GPU/CPU resource residency. Headless success alone is not graphics evidence. A video alone is not UI responsiveness evidence.

No unrelated 50× speed target or arbitrary universal GPU budget is introduced. Preserve existing bounded live lookahead/media limits; give scene publication priority, amortize thumbnail work, and measure long recordings with collapsed and expanded tracks. Large time jumps may prepare asynchronously with honest progress; ordinary playhead motion, scrolling and resize must not repeatedly compile, reupload or block on whole-case work. A discovered regression must be fixed or explicitly documented as blocking, not hidden by averaging.

Required review roles throughout implementation:

- **Plan-adherence reviewer:** tracks this full scope and accumulated user feedback; calls out polishing tiny isolated details while required base mechanics/layers/conditions remain missing.
- **Anti-slop reviewer:** checks duplicated resolution/scheduling, invented catalogs/services, content-specific patches, fake thumbnails/coverage, uncontrolled scope and loss of TS/Pygame behavior.
- **Anti-OOP/correctness reviewer:** checks passive authoritative data, Godot node/resource ownership, finite shared mechanisms, causal commits, particle/audio clocks, async publication and live/offline parity.

Use same-task subagents for these roles; repository instructions prohibit cross-chat communication. A reviewer may combine roles when useful, but each responsibility must be explicitly covered. Review findings need concrete disposition and evidence. Completion includes a concise user report linking the runnable Studio entry point, recordings, coverage, native screenshots/listening examples and performance results, with unresolved required work explicitly preventing a 'done' claim.

## 12. Source map and handoff

Primary client: /mnt/c/Users/tommaso/Documents/Dev/NDClientGodot. Authoring and this plan are tracked; artwork, native imports, audio, captures and temporary recordings remain under the existing ignore policy.

| Source | Reuse or study |
| --- | --- |
| authoring/catalog-index.json and referenced catalog/spell/item/environment JSON | Current adopted source selections, source fields, sockets, layer roles and lifetimes |
| presentation/session.gd, compiler.gd, tracks.gd, timeline.gd, authoring.gd, characters.gd, event_trace.gd | Actual shared production flow and current omissions |
| tools/presentation_scenarios.py, tools/gallery_recording.py, tests/presentation_capture.gd | Existing real-server/current-SDK capture mechanisms |
| /home/tommaso/Dev/NeuroClient/agent_docs/studio_goal.md | Layer/pose-clock hierarchy and preview expectations |
| /home/tommaso/Dev/NeuroClient/app/src/ui/studio/StudioTimelineModel.ts, StudioTimelineLayout.ts, StudioTimelineView.ts, StudioTimelinePixi.ts | Recover useful time geometry, hierarchy, labels and thumbnail presentation; replace fixed-count/synthetic scheduling assumptions |
| /home/tommaso/Dev/NeuroClient/app/src/ui/SpellStudioPreview.ts and ui/spellStudio/timelineBuild.ts | Actual historical layer/phase previews and pitfalls: 15-frame assumptions and fixed-30-FPS seek |
| /mnt/c/Users/tommaso/Documents/Dev/dnd_engine/game_obsolete | Pygame/scenario historical semantics; not a current SDK execution path |
| /mnt/c/Users/tommaso/Documents/Dev/dnd_engine/sdk/protocol/README.md and current server setup/acceptance tools | Current packet semantics and supported real capture routes |
| /mnt/c/Users/tommaso/Documents/assets/VFXFactory/research/lelu-channel-2026-10-13/source-audit/INDEX.md and ../ANALYSIS.md | Broader native library, actual node/material/animation dependencies, depth and runtime integration findings |
| /mnt/c/Users/tommaso/Documents/assets/VFXFactory/factory/core/contract_composition.gd, factory/components/, factory/runtime/ and factory/export/ | Existing native constructors, explicit clock/material bindings, particle simulation and actor bindings; capture stage is not the production world |
| /mnt/c/Users/tommaso/Documents/assets/VFXFactory/recipes/ and docs/PROJECTILE_WINDUPS_HANDOFF_2026-10-11.md | Native counterparts, phase selection, source/heading calibration and distinction between current assignments and additional candidates |

Later spell work proceeds cantrips, then levels in order, with each spell's meaningful recorded interactions and associated conditions. First-chunk framework probes do not certify a whole spell level. New native library entries remain available for authoring without inventing gameplay definitions for them.

### Plan review record

Reviewed against current code, recovered plans, Factory sources and accumulated user feedback by two same-task reviewers on 13 October 2026.

- Anti-slop/scope: no unresolved scope finding. Verified immediate native VFX/blood/material/audio delivery, condition lifetimes, the named base-case set and the requested resizable visual timeline. Corrected the Factory source link.
- Anti-OOP/correctness: no alternate-scheduler or class-framework blocker. Incorporated explicit aggregate-action causality, compact offline indexing versus bounded live trace/lookahead, terminal idle behavior, particle simulation history/thread ownership, occurrence-local materials and once-only capped-light color evaluation. Corrected the master-section anchor.
- The review was document/source inspection only. No implementation, captures, tests, native visual validation or sound audition has been performed for this plan. Required implementation acceptance remains in sections 10–11.

### Accumulated implementation feedback, 13 October

These are user clarifications to the same first chunk, not a replacement task:

- Browse capabilities, their meaningful interactions, and supporting recorded cases. A folder/seed playlist is not the product. Unrecorded requirements must remain discoverable.
- The timeline is a worklist of required presentation, including effects and conditions that have no renderer yet. Derive expected components from authoring, preserve JSON pointers, and distinguish absent authoring, absent native conversion/support, unavailable sources, and unverified behavior. Importing every asset is not required to record those gaps.
- Combine the available faction recordings for inspection and allow switching the rendered faction at the same causal occurrence. Preserve each original SDK prefix and its own reduced state. Never invent an omniscient packet or treat audience-local sequence numbers as shared event identities.
- Put effects, missing requirements and retained condition lifetimes beneath their actual causal owners, using authored intervals where known. Unresolved timing is explicit. Internal undisclosed/turn/sensory scaffolding belongs in metadata inspection and must not crowd out meaningful tracks.
- Fit time to the available width; use vertical space for actual previews and missing requirements. Keep the rendered preview and resizable timeline as the main workspace.
- Resolve blood attachment and front/back composition mathematically before appearance tweaks: impact origin is immutable, detached particles do not follow a later recipient pose, and the declared actor presentation plane partitions original native fragments before blending. Estimated optical receiving depth is not certified physical sorting geometry. Scenery crossings still require separate qualification.

### Current delivery priority — explicit user correction

Finish the Studio workspace and authoring worklist now, so VFX implementation can
proceed through its tracks. Do not multiply preview cases or continue native VFX
polish as a prerequisite. In particular, identify what is missing **from the
authoring JSON**, independently of existing media references and current renderer
support. The current Studio gate is a usable organized browser, causal/split
timelines, actual previews for supported components, precise missing-component
lanes, and a searchable/copyable authoring audit. Unsupported VFX stay explicit.

This changes the immediate delivery gate above; it does not declare all planned
effects complete. Further native Hold phase/scenery integration, Magic Missile
control mismatches, sound polish, and the Gallery performance comparison remain
subsequent VFX/integration work. No new artwork is imported by this audit.

The offline denominator comes from `tools/studio_content_catalog.py` using the
current backend content manifest. `studio/authoring_audit.gd` joins that snapshot
to live authoring; `presentation/condition_coverage.gd` owns detailed condition
requirements. The worklist separates missing authoring/ownership decisions,
missing sources, native migration, renderer gaps, and unexercised assignments.
State-only and explicitly disabled choices are preserved. Ground indicators link
to their existing spatial authoring rather than being counted as absent actor
effects. Saved audit output is `generated/studio_authoring_worklist.json`.

The user's subsequent screenshot correction requires a clean default timeline:
unseen audiences, empty branches and undisclosed text take no rows. Flatten a
single useful faction view; retain terse split labels only for meaningful
alternate presentations. Keep missing requirements visible as compact tracks,
with technical explanations and full source pointers in the inspector/tooltip.
The full index remains available for navigation and explicit metadata inspection.

### Hide and native Resource authoring — next user-selected capability

The user selected Hide as the first capability to complete, and explicitly chose
native Godot Resources instead of new JSON for new presentation authoring. Keep
the adopted legacy JSON intact. Select passive `.tres` recipes at the common
catalog boundary; expand finite typed body-pose/filter/feedback operands and
reuse the existing compiler, condition lifetimes, renderer and shader functions.
Do not introduce a Hide renderer, controller, shader or separate Studio schedule.

Requested Hide appearance is an actual crouch animation and partial transparency.
Verify the modular source frames and adopt CrouchIdle/CrouchRun with explicit
source registration/clocks; do not rename a standing clip. Idle and movement
selections must leave attack, hit, jump and death arbitration intact. Visibility
and condition removal remain authoritative per audience. Invisibility's magical
transparency is a separate future selection.

The Pygame condition feedback fields describe +/- text badges, not body flashes.
Correct that shared interpretation and retain independent badge lifetime. Native
Resources and their properties, plus original JSON provenance, must be inspectable
in Studio's existing source/coverage worklist; available cases are not the catalog
denominator. Missing source/unsupported/unexercised states remain distinct.

Validation uses the existing real Hide paired recording: application, sustained
crouch/movement, attack/removal, faction visibility, reverse seek and reload;
native source previews and assembled-character captures confirm pose/opacity.
Check resource immutability, candidate reload and existing condition composition.
Plan-adherence/anti-slop and anti-OOP/correctness reviewers remain on this chunk.

#### Earlier Hidden-condition evidence — not complete Hide action acceptance

The selected native recipe now uses actual `CrouchIdle`/`CrouchRun` sheets and
the shared 0.55 opacity filter. Their 15-frame, 12 FPS clock is explicitly
authored here; the source handoff supplied no adopted crouch FPS. Existing attack,
hit, connector/jump and death arbitration is preserved. Condition transitions
emit the recovered +/- text badges; their shared foreground ordering was fixed
after a native capture exposed clipped glyphs.

Native Resources resolve at the common source catalog boundary. Compiler-selected
recipes feed existing attack/action/spell/condition diagnostics, removing duplicate
variant selection. Session preparation, media planning, Studio candidates and
thumbnail jobs receive the admitted immutable source snapshot. Review/native
validation found and fixed independent Resource reloads in seek preparation and
thumbnail generation. Invalid Reload preserves the prior world, clock and sources.

Evidence in `generated/`: `native_authoring_checks.json` (273/0),
`condition_pose_checks.json` (343/0), `component_trace_checks.json` (45/0),
`studio_seek_native_authoring_checks.json` (2550/0 across Hide's two factions,
Hold Person and action economy), `condition_coverage_checks.json` (2601/0),
`studio_native_condition_checks.json` (23/0), and
`studio_inventory_headless_checks.json` (36/0).
The earlier `studio_hide_render_checks.json` recorded 741/0 native Forward+ checks: four views,
actual assembled sources and gear/normal registration, opacity coverage,
unchanged attack clip, authoritative removal, unseen faction exclusion, exact
reverse-seek actor pixels, actual timeline thumbnail revision isolation and
rejected reload retention. Captures are in `.captures/studio/hide-native/`;
`.runtime/studio-hide-render-qualified.log` is clean.

Those checks did **not** prove an event-owned `action.hide` body. The legacy action
remained body-disabled, so the preview could begin after Hidden applied. The user
correctly rejected that as completion of Hide. Other-rig crouch selections, magical
Invisibility and remaining VFX are not implemented by this delivery. The complete
catalog still records 18 missing persistent indicator assignments. Existing native
VFX retain their current source catalog; this is not a wholesale Resource conversion.

#### Hide action correction and bounded preview timing — 14 October

The required sequence is normal idle → Hide action → sustained Hidden with
crouch idle, sound and partial transparency → crouched movement. A condition
sustain sample cannot satisfy the action's expected body requirement.

The selected passive `actions/hide.tres` now owns `CrouchIdle`, playback speed 3,
effect frame 15 and `hide_transition`. With the adopted 12 FPS source this gives
a 416.667 ms body; the real child Hidden commit and cue start at its end. The
installed modular library has no dedicated standing-to-crouching entry clip.
This is a new authored reuse of an already-crouched clip, not a recovered smooth
transition or newly generated art. The cue is a temporary sourced CC0 quiet
swish. Existing compiler scheduling, condition ownership and renderer mechanisms
remain shared; no local condition or outcome is invented.

Studio records passive absolute starts on wrappers of the original compiled
groups: 500 ms of the initialized SDK state before the first operation, and
350 ms between operations with rendered body/components. Lineages and metadata
events receive no independent delays. The shared Timeline observes these starts
on both immediate and prepared-world paths. Live groups carry no preview start;
their behavior is unchanged. The real paired Hide regression proves the original
groups, commits and final state remain exact, including rejected/unready world
boundaries and reverse seek.

Current headless evidence: `studio_timing_checks.json` 117/0;
`studio_seek_timing_checks.json` 1029/0; native Resource admission 286/0;
`studio_authoring_audit_checks.json` 6516/0. Selected action clip and cue-assignment
provenance link to exact `.tres` properties; the cue retains its separate audio
source and inherited fields retain their JSON pointers. The capability report
requires a positive-duration body owned by the actual Hide event, keeping child
condition samples and unrelated context gaps separate. The replacement native
action/audio acceptance now passes **1139/0** in
`generated/studio_hide_render_checks.json`, with clean
`.runtime/studio-hide-transition-final.log`. Continuous playback records 78 idle,
59 action and 33 Hidden frames without a boundary violation. The first Hidden
sample and exactly one native cue crossing/shot occur at 916.666667 ms; audio mix
peak is 0.010197. Four views, recorded Attack3/removal, Blue visibility, reverse
actor pixels and rejected reload remain covered. One-byte glyph edge blending is
reported explicitly; no shader appearance change was made for that oracle.
The historical 741 checks remain condition-only evidence, not a substitute.

The long tail was a client-created ground deposit, not other-faction padding.
Before preview spacing, Amber's semantic/presentation ends were 3471.0176 and
6221.0176 ms (2750 ms tail). With the same current 500+350 ms spacing, removing
only that invented deposit changes 4671.0176/7421.0176 to
4671.0176/4821.0176 ms: the tail is now 150 ms of real feedback, 2600 ms shorter.
No actual event or audio is skipped and no arbitrary horizon clamp was added.

#### Authority review and deliberately deferred work

The latest user direction defers blood implementation and appearance work;
remove inventions and identify missing authoritative rendering instead.

1. **Fixed:** damage alone no longer manufactures blood. Airborne blood requires
   the disclosed `body_release.release_id == body.blood`; no ground deposit is
   created. Nonempty authoritative residue regions remain an explicit missing
   renderer requirement with unresolved state-owned lifetime. The real Hide plus
   passive boundary regression passes 72/0 (`blood_authority_checks.json`).
2. **Fixed:** destroyed prop/wall selection and separation of mixed-state corner
   joins preserve the actual recorded state. `world_authority_checks.json` passes
   45/0 across five real destruction after-values and existing sources for four.
   This is source/publication evidence, not a new native image qualification.
3. **Next existing rendering defect:** spatial trap state and its source-cache
   invalidation must follow authoritative trap observations. It is identified,
   not silently represented as fixed by the destruction checks.
4. **Missing authoring:** the destroyed torch lacks a selected remnant source.
   Do not replace that gap with an invented intact or hidden visual.

No production prediction or local HP/condition/position outcome generation was
found in the scoped source audit. This does not certify every rendering adapter;
the named remaining gaps stay visible in Studio. No broader effects import or
backend work is authorized by this correction.

#### Next authorized step — visual bright/dim light ranges

The user asks for Godot light radius/level mapping to reflect the backend's bright
and dim ranges so the Hide scene is visually coherent. Study the actual server
light observations and native light configuration, then correct that mapping
within the existing light renderer. The server continues to own Hidden, detection
and contact visibility; do not implement client stealth rules or claim bright
light universally removes Hidden. Compare finite known-range scenes and the real
Hide recording before claiming visual/rule agreement. No blood implementation or
broader rendering rewrite is included. Keep plan-adherence/anti-slop and
anti-OOP review active for the measured mapping change.

Current source study confirms that the rule was not removed:
`dnd/actions.py` rejects Hide in `VERY_BRIGHT`; `dnd/conditions.py` removes
existing Hidden on a light-change event or entry into a `VERY_BRIGHT` tile.
Ordinary `BRIGHT_LIGHT` does not itself remove existing Hidden. The regression
`tests/manual/test_135_stealth_lighting_legacy_contract.py::test_torch_zones_preserve_bright_hidden_and_reveal_very_bright_hidden`
explicitly distinguishes them. Use objective `tile.resolved_light` for this
comparison; `senses.effective_light_levels` can include observer darkvision.

Further inspection found an important recorded-data limit: the current public
SpatialFact has no objective light map. Objective light arrives only in tile
observations/field patches, and this recording retains stale tile light values
while sensory facts report different levels, including at initialization. Thus `tile.resolved_light` is
**last observed objective light**, not a certified current map. The current
audience-effective map is explicitly observer-relative and can include special
senses. Display those meanings separately and expose disagreement; do not relabel
either as the other or infer missing objective values. The later user instruction
to iterate until rendering matches authorizes the minimal projection correction
described below; the earlier client-only limit no longer applies.

The current client preserves very/bright/outer radii but only the outer radius
scales a generic PointLight2D cookie. The engine combines source levels by MAX
and applies darkness caps, while native Canvas energies add. These are confirmed
mapping gaps, not completed fixes. A portable torch's current 10/20/+20 ft
radii describe VERY_BRIGHT through 2 cells, BRIGHT through 4, DIM through 8,
subject to the engine's optical occlusion. Do not equate render brightness with
a new client-side gameplay classification. Native normals, source colour,
optical height and the existing colour-preserving cap remain relevant constraints.

##### First-pass light profile — partial evidence, not completion

Use the existing PointLight2D page adapter. A shared native cookie/profile can
encode the admitted very-bright/bright/outer radius ratios; it must not introduce
a second light loop, client light-level reducer, ambient boost or stealth rule.
The level-to-energy profile is an explicit presentation choice: the backend
supplies categories and ranges, not physical intensity values. Preserve source
colour, native normal response, sampled emitter position/height and the current
colour-preserving accumulation cap. A radial cookie alone does not establish
MAX composition, darkness caps, optical wall occlusion or exact projected ground
distance; report those limits unless the same bounded implementation proves them.

The first pass uses the following finite comparisons. They qualify the profile
and diagnostics only; the agreement gate below supersedes them as completion:

1. **Actual objective data:** select a real admitted torch recording containing
   `DIM_LIGHT`, `BRIGHT_LIGHT` and `VERY_BRIGHT`, and record the source's exact
   three feet values plus observed tile positions/levels. Check interior, boundary
   and exterior tiles against those observations, including a diagonal; first
   establish their observation boundary, since a retained tile can be stale. Do not
   recompute marker categories from image brightness or the cookie. The current
   Hide recording's initial Amber observation has 214 tiles, all `DARKNESS`; that
   frame alone is insufficient. Its later packets supply 19 DIM, 6 BRIGHT and 12
   VERY_BRIGHT tile rows in each faction. Their presence alone does not prove
   freshness for every cell: report objective/effective disagreement and retain
   initialization as the last-observed darkness control.
2. **Inspectable native mapping:** capture the same flat receiving source under
   each actual zone with cap enabled, then with cap disabled as a control. Confirm
   that the chosen profile retains useful dim/bright/very-bright separation at
   the approved default strength; do not hide a saturated plateau by changing
   source colour, normals or exposure. If projection prevents exact world-distance
   correspondence, label the discrepancy rather than calling the rings exact.
3. **View and source invariants:** repeat the finite source/zone samples in all
   four quarters and two existing zoom levels. Emitter world contact, optical
   height, native normal orientation, alpha/support and source registration must
   stay correct. Moving or extinguishing a disclosed light and removing its
   visual contact must update every attached page without stale cookies.
4. **Truthful Studio markers:** label the overlay **Perceived light**, sourced
   only from displayed `senses.effective_light_levels`; it is current
   audience-effective light and may include special senses. Never fall back to
   `tile.resolved_light`, which is last observed objective light without certified
   freshness. Retain objective/effective disagreements in diagnostic evidence.
   Restrict markers to disclosed visible cells and never infer an unseen cell. Marker toggles
   change neither the rendered scene underneath nor canonical state, clock,
   light energy, visibility or condition ownership. Turning markers off restores
   the original scene pixels.
5. **Real seek and boundary behavior:** seek backward/forward across an actual
   light change and switch factions; markers and native lights must use the
   displayed committed snapshot, with no future Session state. Recheck the real
   Hide action/effect/removal sequence. Ordinary bright light and very-bright
   light remain distinct server outcomes; no client clears Hidden.
6. **Honest overlap control:** include two overlapping lights and a disclosed
   occluded/darkness-limited observation if available. Verify the marker values
   exactly match their labeled displayed-state fields regardless of native colour. Any remaining
   MAX/cap/occlusion disagreement is named separately from the corrected radius
   profile, not disguised by a pixel-derived rule or extra ambient light.

Headless metadata assertions establish source/state boundaries. Native captures
establish appearance and toggle restoration. Neither proves the other's scope.
Server rule changes, blood work and source artwork remain excluded.

The legal `hide-light-seed3` capture now supplies finite post-command evidence:
Blue extinguishes/reignites its actual torch, then moves to disclosed positions
(10,6), (7,6), (6,6). Both original journals report objective and perceived levels
2, 3, 4 at the stationary Amber actor's sampled tile (4,6), at their retained
cursor boundaries 8, 13, 14. The same Hidden instance survives dim/bright and is
removed by the real very-bright event. Blue already has visual contact in the dim
sample, showing that detection and condition removal are separate outcomes.
`capture-result.json` records 30/0 after-value checks and the actual commands,
receipts and per-audience cursors; each journal passes 119/0 strict SDK/compiler
checks. This does not repair or reclassify the old initialization discrepancy,
and does not certify arbitrary tile observations as a current objective field.

##### Active continuation — iterate until the rendered light field agrees

The user explicitly asks to **iterate until they match**. The completed radial
profile is insufficient. Its 105 headless checks and 108 native optical-plane
checks establish inner-range use and visible intensity separation; the 908 native
overlay checks establish truthful perceived markers and reversible source rings.
They do not establish that the actual receiving world matches the server's light
field. Keep the task open until the finite agreement cases below pass, or identify
the exact unresolved discrepancy rather than replacing that gate with cookie-only
evidence.

There is now a concrete disclosure failure as well as a receiving-coordinate
gap. In the legal paired capture, Amber's sequences 8, 13 and 14 contain current
objective/perceived levels 2, 3 and 4 at (4,6), but its admitted state produces
zero native light sources. The visible Blue actor's private torch is absent from
Amber's public loadout. Blue's own separate journal supplies that source. A
brighter cookie cannot repair Amber's missing input. Neither the renderer nor
Studio may borrow the other audience's private state or reconstruct a torch
from a light category alone.

**Authorized boundary.** Inspect and, where necessary, correct the smallest
server/SDK projection of authoritative illumination needed by the existing
renderer. This may include initialization freshness, current objective field
updates, or permitted emitter/influence data. Reuse existing public fields where
they suffice; do not expand full actor inventory disclosure merely to obtain a
light. Choose the representation after inspecting the actual producer and native
receiving coordinates. Any added data must obey the same audience visibility,
ordered operation, initialization/replay and commit boundaries as existing state.
No server light, perception, Hidden, detection or contact rule is to change. No
client stealth rule, independent light simulation, scene-specific light, extra
ambient fill or second rendering pipeline is authorized.

The native implementation must account for the authoritative spatial reach and
combination actually required by these cases, including occlusion and MAX
composition; these are no longer acceptable reasons to declare the task finished
with disagreement. Preserve the shared renderer, source colour, source height,
normal response, alpha/support registration and colour-preserving cap. Change
receiving coordinates or light data plumbing only where the source study proves
that the existing interpretation prevents agreement. Do not invent a requirement
for physical irradiance, PBR parity or a new photometric model: the server gives
gameplay categories, not absolute radiometric units. The chosen visual intensity
for a category remains explicit authored presentation data.

**Agreement acceptance.** Retain the actual source records, audience/cursor,
displayed commit and native captures for each comparison:

1. Replay both real Amber and Blue views through the existing 2/3/4 observations.
   Both rendered worlds must receive enough authorized illumination data to show
   the corresponding dim/bright/very-bright regions at the actual receiver
   positions. A neutral known receiver isolates field intensity from material
   tint and normal-facing response; use the real scene as the integration check.
   Do not classify gameplay levels from arbitrary final RGB thresholds.
2. Exercise actual source off/on and movement, an optically occluded receiving
   region, and two overlapping sources whose server result is MAX. Include
   relevant darkness limiting when available in the existing legal setup. Check
   the current authoritative result rather than counting sources or declaring
   that native additive lighting is close enough. No source may survive after
   its permitted lifetime or leak across audience changes.
3. Compare interior, boundary, exterior and diagonal receiving positions through
   all four camera quarters, two zoom levels and existing supported elevation.
   The receiver's world location determines field membership, not screen-space
   distance from the projected emitter. Actor body pixels retain native normal
   shading without moving the gameplay footprint with sprite height or view.
4. Cover initial state, incremental light changes, cold replay, backward/forward
   seek and faction switches. The displayed field must use the corresponding
   committed state, never a future Session state or a stale initial tile value.
   If projection changes are required, test actual server-to-SDK values and
   audience boundaries in addition to native rendering.
5. Keep perceived and objective diagnostics separately named. Perceived light
   may include special senses. Objective markers may become current only after
   their producer/update contract is established; until then, retain the existing
   explicit last-observed limitation. Marker/ring toggles must restore identical
   underlying pixels and leave clocks, state, lighting and condition ownership
   unchanged.
6. Preserve the real Hide sequence: one Hidden owner survives dim and ordinary
   bright and is removed by the actual very-bright event. Existing visibility
   contacts are separate evidence; the renderer never creates/removes Hidden or
   changes a detection outcome to make the picture agree.

Root owns integration and serialized native acceptance. Same-task source reviews
cover the authoritative projection and native receiving coordinates before their
implementation is selected. The plan-adherence/anti-slop reviewer checks that
partial profile/overlay success is not substituted for this gate; the independent
anti-OOP/correctness review checks passive projected data, audience ownership,
ordered publication and reuse of the existing native renderer. Keep findings and
remaining discrepancies in this plan. Broader VFX/blood work, unrelated server
optimization and renderer redesign remain deferred.

**Superseded field-rendering proposal — not authorized by the latest correction.**
The implementation described in the next paragraphs was stopped. Its canonical
chart, per-cell masks/allocation and ambient redistribution have been removed.
Only the optical-source publication remains within the latest scope below.
The user permits an unseen
emitter's optical position and its contribution to currently visible cells; the
projection must still withhold hidden actor/item identities. map_audit owns the
minimal server projection: exact active source observations/visible footprints
and current objective tile updates, including source changes that leave the
aggregate MAX level unchanged. Such a change must invalidate the illumination
observation without manufacturing a gameplay light-change outcome or clearing
Hidden. Existing tile-field updates carry objective values where sufficient.

render_audit owns the native receiving-coordinate adaptation inside the current
atlas. A canonical world-XZ chart selects source-cookie contribution; the painted
pixel remains the native LIGHT_VERTEX input, with the existing normal basis and
source optical height. Canonical bounds serve native light culling while actual
screen visibility remains separate. Root owns native source cookies built from
the published contributions and normalization against the authoritative final
level/darkness limit. This uses native PointLight2D accumulation, not a custom
Godot light loop or another gameplay light solver.

Before acceptance, prove zero contribution on absent/blocked cells, including
filtering at their edges; correct asymmetric/mixed-level overlap; source off or
movement under unchanged aggregate MAX; and the initial, removal and empty-view
cases. Normalize the source allocation once in an explicit energy convention,
so another source or a repeated energy multiplier cannot silently raise the
neutral receiver above its authored objective target. Native normal/colour
responses remain presentation and are checked separately from that target.
Exercise all attached receiving pages and cap/Normals/resize transitions. Old
recordings without authoritative source observations retain a clearly identified
legacy fallback; they cannot be cited as field-agreement evidence or silently
upgraded by invented source data. Current source changes and these validations
are in progress; the 105/108/908 first-pass results do not validate this design.

##### Latest instruction — calibrate the existing native lights only

The user explicitly corrects the approach: do not make a new lighting system;
calibrate intensity, radii and colours of the existing native PointLight2D path
to the engine. This supersedes the field-rendering proposal and its architectural
acceptance requirements above. No canonical lighting chart, per-cell rendering
mask, source allocation against MAX, ambient redistribution, receiver-shader
rewrite or custom light loop belongs to the current implementation.

The approved optical-only source observation is still needed so the native
renderer can display an unseen emitter's light without disclosing hidden actor
or item identities. Integrate those passive schema-9 observations through the
existing SDK sensory composer. An explicitly present empty source dictionary is
authoritative; absence in an archived recording retains the legacy path. Current
live protocol identity remains strict, while Studio explicitly selects archived
schema 8 for older recordings. Per-source footprint data is diagnostic input,
not a mandate to render a new per-cell field.

Use native light scale/texture offset, source colours, energy and radius profile
to calibrate the existing optical path. Preserve the normal-lighting origin and
height, approved source registration, cap and authoritative event/Hidden rules.
Validate real Amber/Blue source visibility, off/on/removal, source updates whose
aggregate level stays unchanged, four views/zoom/elevation and the original
normal response. Compare the actual dim/bright/very-bright scene and report
remaining native additive/occlusion differences honestly; do not solve them by
reintroducing the rejected field system. The reviewer gate is now fidelity to
this narrowed calibration task, not completion of the rejected redesign.

Schema-9 Godot intake is now implemented. The unchanged delivered schema is
installed and schema 8 is archived for explicitly historical Studio reads. The
focused SDK suite passes 411 checks, including exact Python parity across all
30 recorded Amber/Blue prefixes, multi-observer source/tombstone composition,
immutable public snapshots, reset/removal behavior, and continued strict live
identity rejection. This qualifies passive data intake, not new light rendering.

##### Latest base-mechanics continuation — complete ordered actions and sound

The user now requests all base actions, weapon attacks, opportunity attacks,
dying and blood, properly ordered, using the Pygame presentation as the reference.
This supersedes the earlier blood deferral. It does not restore client-invented
blood outcomes: disclosed release/residue authority and causal ordering still
apply. Finish the useful Studio presentation rather than only suppressing missing
diagnostics. Keep native scene and renderer reuse, exact server outcomes,
condition-owner lifetimes and explicit authoring provenance.

scope_review owns Dash, Dodge and Disengage condition presentation through passive
native Resources and the existing shared condition mechanisms. Their authored
body-disabled actions remain body-disabled unless the user selects a body action;
condition indicators must be visible during their actual owners' lifetimes and
restored correctly on seek/removal. Application feedback alone does not satisfy
the persistent-indicator requirement. Root owns general audio cue selection and
licensed source bindings; prefer the existing CC0 collection and document actual
licenses. Render work on blood/attacks stays in its assigned shared pipeline.
Tests must distinguish an actual recorded mechanic from a newly authored visual
choice, and confirm action/effect/condition/audio order rather than merely source
availability. Close all Godot processes at the end as the user requests; do not
leave an interactive preview running while they are asleep.

Dash, Dodge and Disengage now have selected passive condition Resources. Their
legacy Pygame recipes contained feedback but no persistent visual, and their
action bodies were disabled. The new authored choice is a thin assembled-body
contour in each recipe's original application-feedback colour, using the shared
Pygame contour mechanism. It does not add a gesture, alter the body/source alpha,
or represent a recovered per-action effect. The common `PresentationBodyOutline`
Resource supplies the existing contour operands; no new effect renderer or
shader is introduced. Exact `.tres` properties and inherited JSON pointers remain
visible in the inspector and coverage report.

`basic_condition_checks.gd` passes 201 checks over the actual Dash, Dodge and
Disengage journals. It verifies recorded UUID application/removal, shared
selection, indexed source provenance, rejected Resource reload isolation, and
unchanged state commits, group durations and body tracks compared with the same
recipes without the new contour. `basic_condition_render_checks.gd` passes 153
checks in native Forward+: all three actual owners are visible in four quarters,
mute/unmute restores identical pixels, pre-application and post-removal have no
contour, and reverse seek restores it. Captures are under
`.captures/studio/basic-conditions/`. This is finite indicator acceptance, not
completion of the remaining weapon/reaction/death/blood/audio cases.

The equipment presentation now follows the original Pygame context through the
shared body resolver: modular Taunt at 3× speed, equipment commit at source
frame 4 (111.111 ms into the 416.667 ms body), and existing per-rig overrides.
Actual Hide/torch recordings pass 189 semantic checks for original commit order,
before/after loadout, source frame and reverse restoration. This restores a real
preceding recorded operation, so historical Hide tests' absolute 500/916.667 ms
boundaries are not current acceptance clocks; future native checks must derive
the action and effect times from the compiled index.

The ranged Attack3 weapon-trail diagnostic now uses the original eligibility:
an equipped melee source with no projectile. It still reports an eligible melee
pose whose trail is missing. The focused component trace suite passes 48 checks.
Frenzy now selects the already installed original ClassComponents ground source,
its exact `#78262b/#da393f/#f07b68` palette and original 100 ms offset/950 ms
recipe lifetime. No source artwork or effect renderer was added. Eleven source
checks and 50 native checks pass on the real occurrence, including four camera
views, visible pixels, exact mute restoration, unchanged canonical state/clock,
and no effect before or after its lifetime. These remain finite capability
results; ordered blood, death and sound require their own acceptance.

The earlier 29-recording audit exercised the then-implemented requirement checks.
It did not enumerate all authored operations or every Pygame presentation owner.
Its former “no missing compiled requirements” result is superseded as a coverage
claim by the source-derived audit below. Existing native/audio results remain
evidence for their finite tested components; they do not close newly exposed
inspection, renderer, source or unassessed-owner gaps. Re-run
`tools/studio_base_capability_audit.gd` against the current requirement projector
when assessing a recording. The original three explicitly accepted potion actor
strip omissions remain distinct from required, unsupported sibling media.

The current full Hide native rerun passes 1139 checks with preceding equipment
enabled. Its actual action runs from 1266.667 to 1683.333 ms; Hidden and exactly
one sound crossing begin at 1683.333 ms. The fixture samples the real preceding
idle interval and records 29 idle, 60 action and 33 Hidden forward frames with
zero state/source/alpha boundary violations, then checks four-view sustained
idle/movement, removal, both factions and reverse restoration. This supersedes
the old absolute-time evidence without changing the action's 416.667 ms duration.
The combat timing suite passes 1750 semantic checks across damage, dying, lethal
opportunity attack and revival. The real Dying/death-save/Dead case also passes
35 native checks, including 571 continuous frames, the witnessed corpse and its
retained terminal Die source pose. Expanded licensed audio passes 555 causal/source
checks across 29 real recordings and 49 native checks
covering thirteen recorded cue types. Native PCM proves these selected cues play and
respect their authored single-voice gain; final artistic mixing and arbitrary
concurrent-voice bounds are not claimed.

The blood continuation now renders the actual disclosed ground release through
the installed Pygame particle and liquid-kernel data. The renderer batches
airborne pieces by the existing painter-cell ordering, partitions the recipient
cell around its assembled body, and samples the existing native 2D receiving
light pages. It does not infer receiving cells, a deposit ellipse, gameplay
elevation or a residue amount from the actor or from damage alone. Named initial
tile snapshots and the real post-update residue values preserve earlier stains;
the authored particle landings reveal only the new increment. Airborne releases
with empty regions, including the recorded lethal jump, remain air-only.

Current evidence is `blood_residue_checks.json` (281/0),
`blood_authority_checks.json` (69/0), and `studio_blood_residue_checks.json`
(67/0 native Forward+). The native case is the actual Dash opportunity injury
`043585c5-2a45-4e6c-98e6-b68b0d2b9c1e`, Amber sequence 3. It runs continuously
from initialization through impact and landing without seeking, checks twenty
new surfaces despite Timeline retaining the same tile-map shell, then checks
four quarters, exact reverse field bytes, unchanged paused/settled uploads and
the actual red/transparent Studio source thumbnail. An isolated value/lifetime
probe verifies bounded preparation, no future canonical publication, and
cancellation cleanup. It does not fabricate a removal in the recorded journal.
The native liquid field has maximum error 0.004704 across 81,920 samples against
the independent float32 Pygame formula, consistent with RGBA16F additive storage.
No final-colour byte-equivalence claim is made.

The earlier all-at-contact allocation peaked at 20.372 ms. Field resources now
prepare privately through the existing component preparation gate, at most two
tiles per frame, and become visible only with the admitted residue and authored
landing. The final diagnostic measured preparation median 0.359 ms with one
15.666 ms cold native page/material setup; warm flight/landing CPU median
1.195 ms, p95 7.213 ms, maximum 7.772 ms; settled median 0.173 ms, maximum
0.228 ms. This is a finite twenty-tile measurement, not a strict budget or a
claim of map-independent idle cost. Raw frame samples remain ignored at
`.runtime/blood-native/cpu_samples.json`. Native log:
`.runtime/studio-blood-residue-final-prepared.log`; captures:
`.captures/studio/blood-residue/`. The owned Godot process exited cleanly.

Reproduce the independent field inputs with
`tests/prepare_blood_liquid_reference.py --operation .runtime/studio-cases/dash-seed3/amber/journal/0000000000000003.json --authoring authoring --output .runtime/blood-liquid-reference`,
then run `tests/studio_blood_residue_checks.gd` in Forward+/Vulkan with
`--recording=res://.runtime/studio-cases/dash-seed3/amber/journal`. The renderer is
qualified here for the original physical-blood vocabulary. Elemental/frozen
blood response variants, all arbitrary scenery crossings, and general map-scale
residue performance remain separate work; no new artwork or native Factory
source was imported for this continuation.

### User correction, 14 October: Studio is the renderer-completion tool

The active task is the study/inspection framework. Choose meaningful behavioral
sequences independently of their animation models; model capabilities one by one
later. Neither working output nor successful compiled requirements defines the
expected presentation denominator. The recovered plan section 8, Pygame's
presentation inventory and effect consumers, current engine facts, and canonical
authoring jointly define what Studio must expose.

For each study, keep required transitions and participants, actual server-recorded
behavior, authored visual/audio operations, and implemented/missing rendering
visible together. An unrecorded study has no invented absolute timeline. A real
recording supplies the causal owner and time for expected and executable tracks.
Every event-driven graphical operation matters: body/equipment/attachments,
shaders/filters, transforms, conditions, light emission, world transitions,
effects, feedback and audio. A shader or light is not exempt because it has no
spritesheet. Expose target, owner, source, parameters and lifetime; distinguish
missing assignment, missing implementation/source and unqualified output.

The complete named base interaction catalogue lives in
`authoring/studio/scenarios.json`; the requested Markdown is generated from it at
`agent_docs/BASE_ACTION_SCENARIO_CATALOG_2026-10-14.md`. Entries contain specific
ordered sequences and participant roles. Shared testing contracts appear once,
not as boilerplate pretending to be per-scenario coverage. Partial recordings
retain their explicit gaps; the old Dash/OA sample does not qualify a normal
movement versus Dash comparison. No new Dash effect model is part of this task.
The unrequested Dash contour assignment is removed; original conditional movement
media remain visible missing renderer work.

The UI must expose all participants, including defender TakeDamage and method
recipients. Selected tracks play their actual intervals; playback loops by default
or stops at the final presentation boundary when looping is disabled. Preserve
real effect/audio tails without running an empty clock. Dragging the playhead
must coalesce requests, and camera-quarter thumbnails prepare in bounded caches.
Resizing preview/timeline panes preserves map pixel scale and focus. Independent
review covers plan adherence, unnecessary abstractions, event/state correctness,
UI behavior and measured preparation costs. Tests use actual server journals and
native production rendering; a catalogue count alone is never completion proof.

### Source-derived required operations — 14 October

`presentation/requirements.gd` is a passive source-to-expectation adapter shared
by `studio/authoring_audit.gd` and `presentation/event_trace.gd`. It does not
dispatch facts, choose outcomes, or schedule animation. The current schema's
`PlayerNode.fact` discriminator supplies every fact identity, independently of
the recordings. The original `game_obsolete/presentation_coverage.py`
`presentation_inventory` and `lineage_coverage` establish the owner vocabulary:
facts, actions, casts, attacks, shoves, condition lifetimes, rigs/lifecycle poses,
world property transitions, devices/wrecks, portals, spatial/contact/deposit
media, and environment banks/doors/traps/props/remnants.

| Reference owner/consumer | Required operation families | Current inspection treatment |
| --- | --- | --- |
| `game_obsolete/choreography.py::FACT_PRESENTATION`, `dnd/player/reduction.py::STATE_PRESENTATION_KINDS` | All current fact owners; damage/life/steps can belong to a causal parent | Explicit reducer-only families stay state publication. Unclassified facts are unassessed, not silently state-only. Canceled occurrences create no execution demand. |
| `game_obsolete/animation.py::compile_cast`, `sample_cast`; TS `StudioTimelineModel.ts` | Cast body, equipment, recovery, source layers, prepare/travel/impact, target damage and area phases | Existing body/components remain evidence only for their own operations. Hidden cast equipment is an inspection gap; unimplemented recovery is a renderer gap. Disabled area geometry remains explicitly disabled. |
| `game_obsolete/cast_media.py::sample_cast_body_materials`, `cast_media_draw_commands`; `finite_material.py` | Finite source/recipient material envelopes, motes, finite media, cancellation media and actual release/contact clocks | Body-material and media requirements appear even without emitted Godot components. Unresolved clocks remain untimed labels. Outcome-conditional recipes still require their original binding rules. |
| `game_obsolete/directed_media.py::directed_draw_commands`, `animation.py::_compile_anchored_cast`, `choreography.py::bind_choreography` | Arc delivery, directed surfaces/meshes, displacement layers, child-attack presentation and interruptions | Exact selected JSON owners are exposed; an ordinary projectile or cast sprite cannot qualify these siblings. |
| `game_obsolete/body_effects.py`, `condition_draw.py`, `condition_sampling.py`, `condition_animation.py`, `item_effects.py::item_material` | Assembled alpha/material/outline, reveal/dissolve, ghost copies, distortion, absence echo, source-alpha dust, equipment coatings/glints, condition responses and phase crossfades | Existing `ConditionCoverage` remains the detailed condition mechanism owner. Unsupported methods and source registrations remain separate; no duplicate condition catalog or per-effect scheduler is introduced. |
| `game_obsolete/body_action.py::ACCEPTED_SOURCE_STRIP_RECIPES` | Three specifically accepted potion actor-strip omissions, while body/effect timing remains | Accepted omission is explicit and confined to those actor strips. It does not grant omission of other actions, root media or later recipe additions. |
| `game_obsolete/motion_media.py`, `connector_motion.py`, `forced_movement.py`, `portal_animation.py`, `portal_draw.py` | Conditional movement media, connector registration, reaction/recovery intervals, forced motion and independently disclosed portal sides | Movement source selection stays shared with production. Portal and other unresolved ownership is visible even before a renderer exists. A generic move does not qualify all authored motion methods. |
| `game_obsolete/world_animation.py`, `environment_animation.py`, `spatial_media_draw.py`, `spatial_contact_media.py`, `item_attachment_lifetime.py` | Observed object transitions, finite mechanisms, moving/persistent fields, contact triggers, attachments, construction and deposition | Existing endpoint scenery selection is an inspection gap. The separate `world_animations` finite sequences have no production consumer and are renderer gaps; an intact dart launcher cannot qualify its discharge/projectile/contact sequence. Other unresolved world owners remain unassessed. |
| Current `lighting_2d.gd`, audio bindings and shared render consumers | Native light properties, actual visibility publication, audible cue ownership and parameter changes | Recording-specific light/audio evidence remains separate from the passive source inventory. Sensory state publication does not invent a second light animation. |

Actual examples now visible without a working component include Blight's
`/bodyMaterials`, Chain Lightning's `/arcs`, Disintegrate's `/directed`, True
Strike's `/childAttack`, and Heroes' Feast's separate `action_materials` and
`action_intakes` owners. Received non-blood `body_release` identities are not
silently covered by the blood implementation. These examples are source-backed
gaps, not permission to implement all spells in this pass.

Per-spell `damage`, `condition` and `contact` policies are retained as distinct
source owners. The shared damage compiler already honors parent-recipe delay and
callback frames; this is parent-owned evidence, not an extra spell effect. Full
enabled/colour/label/death-policy parity remains unassessed. Outcome-selected
media retain their exact predicates. For example, Blight's save-success and
save-failure materials are separate absent render mechanisms in the catalogue,
but an occurrence whose outcome binding has not been resolved is labeled
**applicability unassessed**; both are never asserted to have executed together.

The classifications are independent: **renderer gap**, **inspection gap**,
**unassessed owner**, **missing source/assignment**, **explicitly disabled or
accepted omission**, and **unexercised**. A source assignment, schema count or
successful compilation never becomes a rendering witness. The catalog lists
unrecorded owners; an actual recording supplies occurrence ownership. No duration
is invented from a default zero, and a working sibling never clears another
required operation. Full parity of every nested Pygame parameter is still work:
unassessed owners remain visible until their actual binding, sampling, source and
render consumers have been checked. This source/consumer census does not claim
that all recovered effects have been visually studied or ported.

### Qualified workspace and transport pass — 14 October

The checklist is closed by default and available through Study. Timeline lanes
contain real source previews, target reactions, explicit body/material restoration,
actual light keys/curves and one waveform across each audio interval. Library
selection updates the displayed case and header together. Required work remains
classified independently of produced components; this pass does not qualify all
animations or spells.

Hidden removal is tied to the recorded condition-removal fact and the composed
remaining state: CrouchIdle returns to Idle and opacity .55 returns to 1 on the
body and equipment in the actual Hide/light recording. Native validation passes
37 checks; unchanged/suppressed/overlapping condition rules retain their existing
shared selectors. Instant restoration creates no invented fade or duration.

Preview generation uses up to eight unchanged native swatch renderers at once,
with byte parity checked across five real recording families. Visible 66-swatch
preparation fell from 973 to 235 ms in the final layout test. Background source
work is bounded and yields to required world preparation. Scroll/zoom/expansion
publish complete layouts with matching input geometry, retaining the previous
complete layout while exact new samples settle.

Studio preloads the recording's finite source set through the existing production
planners and budget selector. The candidate keeps the configured residency budget;
zero-budget eviction and unused live Session construction were removed. The
native interaction run passes 59 checks: first track selection **after case
preparation** fell from 2,221 to 148 ms, warm seeks measured 72/79 ms, and three
loops reused two hosts with a maximum 17 ms boundary hold. Initial media
preparation rose from 843 to 1,862 ms; indexing is separate. No claim of instant
cold loading or residency beyond the configured budget is made.

Final evidence: `generated/studio_transport_checks.json`,
`studio_timeline_preparation_native_checks.json`,
`studio_condition_restore_native_checks.json`, `studio_clip_end_checks.json`,
`studio_thumbnail_batch_checks.json`, and `studio_recording_media_checks.json`.
The native runs use Forward+ on the RTX 5090 and actual server journals. They
verify the stated workspace behaviors, not completeness of the rendering worklist.

### Library navigation correction — 14 October

Capability/interaction menus previously only populated the next selector, and
Library study clicks only displayed descriptions. Recorded selections now open
and play their actual recording. Capability parents expand their studies;
unrecorded studies retain the explicit gap without substituting a replay.
Silent label/preselection updates never issue a load. Reselecting a recording
starts at its beginning; Reload retains the current clock. A later unrecorded
selection cancels an earlier pending load while retaining the displayed world
and its usable faction selector.

`tests/studio_library_navigation_checks.gd` passes 59 native checks through actual
PopupMenu keyboard and Library Tree pointer input: Hide, illumination/reveal,
matching world/timeline/header, autoplay, current-row reselection, rapid changes,
and cancellation. Evidence: `generated/studio_library_navigation_checks.json`.
This closes a navigation gap that the earlier direct-open tests did not cover;
it does not change renderer output or claim instant cold case loading.


### Audio and independent replay perspectives — design and implementation, 14 October

The initial investigation below established the design. The user subsequently
authorized its implementation. The request is for simultaneous
perspectives only in offline Studio/replay playback. Live split-screen networking
is outside this chunk. Movement studies must demonstrate meaningful behavior and
modifiers, independently of whether every visual model has been implemented.
The added brightness request calibrates the existing authored light-range
profile and native CanvasModulate baseline; it does not authorize a new light
system or gameplay rules.

**Initial audio findings; corrected by the implementation recorded below.** The existing path is
already shared with production: `authoring/audio/{bindings,cues}.json` feeds
`presentation/components.gd`, Timeline, ComponentRenderer and AudioPresenter,
which creates native Godot players. Extend this path rather than adding a Studio
sound scheduler. The waveform is decoded from the actual source PCM by
`tools/import_studio_audio.py`, but depicts the source, not output after gain,
attenuation, bus settings or rejected playback. A waveform cannot qualify an
executed sound.

A native Forward+/WASAPI diagnostic reproduced an exact-onset omission. Preparing
while paused at a cue's start records its ID as present. Resuming just after that
start excludes it from one-shot admission in `audio_presenter.gd`. Crossing the
same start from immediately before it starts one voice. In the actual recorded
Move study, full playback started all three footsteps and produced SFX bus PCM;
selecting the first footstep at its exact start omitted that cue and played the
two later footsteps. There were no missing-source or voice-limit errors.
Evidence is `generated/studio_audio_audit.json`; scripts and native logs are kept
in ignored `.runtime/audio-audit/`. The selected-cue probe disabled looping after
selection and continued to study end: it demonstrates admission, not correctness
of selected-range stopping. PCM capture proves mixer output, not loudspeakers.

The current native audio acceptance fixture places sources at the origin and its
listener one unit away. Studio puts the listener on its elevated camera, roughly
19.6 world units from focus. An isolated production-footstep probe measured peak
0.02292 at one unit and 0.01409 at that camera distance (about 4.2 dB lower), with
one voice and no errors in either case. That is a calibration difference, not a
complete explanation of every unheard sound. Actual whole-Move replay peak was
0.01257 in this run. The authored footstep gain is -12 dB. Preserve normal spatial
behavior while establishing an intentional isometric listening point/range.

Other source-backed gaps remain explicit:

- Footsteps currently follow tile arrivals, not sprite foot-contact markers.
- Actor audio passes visual actor-availability filtering, and its runtime
  attachment uses contact placement despite authored attachment semantics.
  General heard-but-unseen/world/UI audio needs its own admitted source policy.
- The concentrating condition's loop assignment is hardcoded outside audio
  bindings. Move that decision into the existing authoring vocabulary.
- A looping row stretches one source waveform across its full lifetime while the
  runtime repeats the source; the preview does not yet describe that time mapping.
- A started-voice witness does not distinguish silence, muted output, attenuation
  and the physical device. Source-ready, scheduled, started, skipped-with-reason
  and measured bus output must remain distinct, with concise UI inspection.

The next audio implementation uses existing components and native players. First
correct exact-onset transport semantics: silent seek to onset followed by Play
starts once; silent seek inside an old one-shot does not retrigger it; resuming an
already-started voice does not restart it; looping admits each intended pass.
Then calibrate the actual Studio listener/mix and honor authored attachments,
loop/time mapping and bus ownership. Native tests must run real Move, impact,
Hide/reveal and selected-row transport, measuring emitted cue IDs and mixer PCM.
Do not substitute the origin-only fixture for those integration checks. Any rate
change must distinguish world travel, body cadence, contact cues and Studio
transport speed; faster walking does not by itself imply pitched-up footfalls.

**Offline split-screen design.** Existing case admission retains independent
faction journals, verifies their shared game/epoch, and restores a fresh Timeline
with copied mutable state. External playback bypasses the live Session. The
SubViewport already owns its World3D. Therefore two passive Play/Timeline/viewport
instances can reuse the real reducer and renderer. Combined inspection rows must
never become executable audience state or leak one faction's deltas into another.

At investigation time there was no shared playback schedule. Existing perspective evidence
shows Hide durations of about 5.44 s and 2.52 s, and Invisibility durations of about
5.23 s and 4.47 s. Equal elapsed milliseconds drift because hidden events collapse
in one view. The current selected-event time mapping is navigation only. Even a
scalar master-to-local-time map is insufficient when several commits share the
same local time: publishing all due commits can reveal later state early.

Use a replay-only comparison schedule derived from common causal/event UUIDs
and per-view lineage, retaining explicit state-prefix boundaries. A common
transport advances both views through their own disclosed animation intervals
and holds the unaffected view during omitted intervals. Do not join packet
sequence numbers or stretch every animation by whole-recording percentages.
Each pane owns its journal/index, Timeline, Play host, World3D, camera, mutable
materials/effects/lights/audio and diagnostics. Share immutable media/cache data
where ownership permits. The replay host must support externally controlled
advancement so its normal process loop cannot independently advance either view.
Seek/loop preparation restores both states privately and publishes the pair only
when both are ready for the same request generation. If one pane waits, the
common clock waits. Account for both active worlds and any prepared spare worlds
in the existing budgets; no new unbounded cache or reparenting lifecycle.

Show two panes when the perspectives differ meaningfully, using concise faction
labels and a common playhead; keep one pane when the study needs only one view.
Link cameras initially and preserve pixel scale on divider resize. Select one
listening faction at a time. Muting the other pane and private candidates must
cover both spatial and nonspatial native players: disabling only its 3D listener
is insufficient. Shared events should seed identical authored randomness from
shared event/component identity, not audience-local operation sequence, so random
particles do not masquerade as a perspective difference.

Replay acceptance uses real Hide and Invisibility differing-duration journals,
plus movement interrupted by opportunity attack, damage and death. At each common
boundary, each pane must equal its own journal prefix. Test pause, reverse seek,
loop, cancellation, a delayed pane, exact hidden/reveal cuts, single-audience
sound, muted private candidates, isolated material/light state, resize/camera
input and combined memory/frame time. No live networking change is needed.

**Movement studies retained.** Keep the short baseline, but expose organized
chapters for a corner, closed door/open/cross/behind-door travel, elevation/stairs,
reaction interruption, and matched ordinary/slowed/boosted travel. All outcomes
come from real server recordings. Show the owner and value of each movement
modifier on the travel/body/contact tracks. Current movement cadence uses
`StepFact.resolved_speed_feet` divided by the authored reference speed; total Dash
movement allowance is not automatically a speed multiplier. Define the requested allowance-to-round-pace mapping explicitly in authoring
and qualify it with ordinary/Dash/slowed/boosted comparisons; its exact values
remain to be chosen. Never derive it from remaining movement points (which would
slow an actor as it spends movement). Do not confuse movement allowance, travel velocity and body clip rate,
or force all sequential action clips into six seconds.

Review remains part of each implementation chunk: the plan-adherence reviewer
checks the study/tool objective; the anti-slop reviewer checks evidence versus
claims, semantic audio/state tests and bounded preparation; the anti-OOP reviewer
checks reuse of passive data, existing owners and native Godot facilities instead
of a duplicate service, scheduler or presentation engine. Implementation and
its finite acceptance evidence are recorded below.


### Bright/dim readability calibration — 14 October

Implemented the requested brighter ordinary light and readable dim surroundings
through existing native controls. The radial Resource now uses .85 at the
very-bright boundary and .70 at the bright boundary (previously .65/.25); its
centre/outer endpoints and radii remain governed by the existing native profile.
CanvasModulate's uniform baseline is .30 instead of .18, shared by atlas creation,
cap switching and normal-preview switching. This also makes already-rendered
unlit/remembered scenery clearer; it does not disclose unknown objects, change
server light categories or remove Hidden. Native source energy/colour/height,
normal decoding, light cap and receiver algorithms are unchanged. The saved
43% light-strength preference was preserved.

The baseline adjustment was selected after comparing existing source intensity:
quadrupling torch energy brightened dim samples but exaggerated directional ground
relief and capped the centre. At saved strength .43, the matched real Hide/light
dim floor sample instead changes from RGB(20.7,18.7,15.8) to(36.4,32.1,26.9).
The ordinary bright sample rises from(39.9,28.1,20.8) to(65.4,46.2,34.3), compared
with the old very-bright sample(59.9,38.0,26.2). These are specific framebuffer
samples, not a universal numeric translation of engine categories.

Validation:105 profile/radius/monotonicity checks;63 native checks with matched
Jump at1.087s and recorded Hide dim/bright/very-bright states at saved.43 and
default1 strength;220 native atlas lifecycle checks, retaining byte-exact equality
with its independently drawn uncapped receiver after sharing the calibrated
ambient value. Both the main agent and reviewer inspected the native captures;
default strength retains surface detail. Evidence is
`generated/studio_light_calibration_checks.json` and
`.captures/studio/light-calibration/`; the existing atlas lifecycle report and
`generated/light_range_profile_checks.json` cover their separate invariants.
No audio transport or split-screen implementation is included in this calibration.


### Audio and offline split-screen implementation — 14 October

Implemented the accepted chunk in the existing component/native-player and
Timeline/Play paths. Audio fixes cover exact-onset admission, silent past-onset
seeks, pause/resume without restarts, authored attachments, condition-loop bindings,
source-loop waveform mapping, per-presenter enablement, and bounded runtime
readiness/dispatch/skip diagnostics. The Studio listener follows focus instead of
camera distance. Only the selected faction is audible; muted UI and spatial
voices consume past onsets without creating a replay backlog.

`Recording.compare_case` builds an immutable common causal schedule from actual
event and lineage IDs. Each view keeps its ordered original deltas and native
animation durations. Independent restores rebuild condition/light/source tracks
through the existing projection. Differing initial visible worlds also require
comparison. Conflicting causal constraints are rejected explicitly. Shared native
effect seeds derive from causal identity rather than audience packet numbers.

Studio now owns a primary and peer SubViewport with separate reducers and native
worlds. Timeline's offline planner includes all commits/groups due at the common
clock, including consecutive zero-time tails. Each pair is prepared and preflighted
before either publishes. The live group/media admission policy remains unchanged. The shared planner also
compares exact terminal cuts on the absolute clock before subtraction, preventing
floating-point rounding from leaving a clamped Move replay busy forever.
Exact per-group media closures are computed by the recording loader against each
private prefix, then promoted through existing budgeted demand only while needed.
Optional preload is not used as proof of mandatory source readiness. Cancellation
and publication release the temporary requirements. Active/spare viewport owners
remain bounded and are never reparented. A rotation/cancellation test found and
fixed prepared painter-order publication against the wrong node membership.

The UI presents two panes, linked cameras, one timeline and a listening-faction
selector. Row diagnostics route to their owning pane; seek/loop preserves that
selection and diagnostic overrides. A single-view path remains for identical
presentations and `--single-view` diagnostics. The approved .85/.70 light-range
Resource, .30 ambient baseline and saved .43 emission preference were retained.

Acceptance uses actual independent faction journals: Hide, Hide/light reveal,
Invisibility and lethal opportunity attack. Native checks cover own-prefix equality,
initial/terminal states, reverse and superseded seeks, two loop passes, a delayed
peer, rotation/cancellation, source readiness, private audio silence and native
Hidden body/gear restoration (.55 CrouchIdle to opaque Idle). Real audio checks
record emitted IDs and SFX mixer PCM for Move, selected onset/inside/loop transport,
melee and Hide/light. These tests do not claim physical-speaker audibility or that
all future spell VFX are implemented.

Reports: `generated/studio_replay_comparison_checks.json`,
`generated/studio_replay_prefix_checks.json`,
`generated/studio_replay_native_checks.json`,
`generated/studio_recording_media_checks.json`,
`generated/studio_audio_transport_checks.json`. Pure alignment and exact-prefix
checks are distinguished from rendered/native mixer evidence. The native report
also includes a separate timing/memory window without reference-restore or image
capture work. Reviewers checked plan adherence, state/media ownership, causal
ordering, native audio and reuse of existing owners; remaining authoring/study
coverage outside this audio/replay chunk stays on the existing worklist.


### Source-contact sound authoring — user clarification, 14 October

The audio/replay implementation must also correct sound placement: landing at the
first actual foot-ground contact within the native clip, and footsteps at source
contact frames rather than tile/event completion. This is part of the audio chunk,
not a request to redesign animation or lighting. Preserve the existing native
transport and compiler; resolve authored source markers through the body's
existing source-time keys so rate changes, seeks and replay alignment agree.

The intended sound artist needs data-owned cue assignment, timing selector,
rig/clip contact markers, source variants, gain, bus, attachment and provenance.
Extend the existing audio JSON vocabulary. Do not introduce a Studio-only sound
timer or bury contact offsets in action-specific code. Missing contact authoring
must remain a visible gap rather than silently becoming an event-end sound.
Document which markers are source-inspected and which cues/assignments still
need artistic review. The actual track and native audio must consume the same
resolved authored timing, with real Move/Jump contact and rate/seek/loop tests.
Plan-adherence and anti-slop/anti-OOP review continue across this addition.


Contact inspection also distinguishes animation/world contact from the audio
file's transient. The current native Rolling jump remains airborne at source
frames 11 and 14 and reaches ground at the unchanged endpoint. Its landing WAV
contains a quiet prelude, with its strongest impact around 81.75 ms. Author an
80 ms source sync point against the actual touchdown marker: the full sound
begins in the final movement frames and the impact coincides with ground contact.
Do not shorten the trajectory, move authoritative commits or treat the earlier
spritesheet foot pose as proof of world touchdown. A prelude that cannot fit in
its admitted owner interval is an explicit authoring gap, not silently clamped.
Studio shows waveform start and the contact marker separately, with the same
source-sync metadata used by native playback and replay retiming.


Source-contact implementation is complete for the reviewed modular clips. Sound
assignment/timing and source transients are data in `authoring/audio/`; its README
documents the artist workflow, semantic selectors, variants, licensing, mix,
attachments and unresolved review work. Contact markers follow the body's source
clock through split tracks, source holds, loops and playback-rate changes.
Comparison retiming shifts cue onset and contact together. Unavailable markers or
preroll are explicit gaps. No movement trajectory or approved lighting changed.

Final audio qualification:54 contact,77 presenter,654 binding checks across29
recordings, and65 native Studio transport checks pass. The native Jump reaches
its destination at1450ms with sprite-ground distance0; landing source offset is
80ms and observed mixer position84.17ms. Real Move whole/selected-onset/seek-inside
playback stops at its exact endpoint; the selected cue loops twice. The separate
18-check real-journal terminal regression verifies clamped steps and a strictly
earlier cut. Creature/window contacts and final professional sound selection are
not claimed complete.

The user's Haste/martial screenshot question adds one narrow preview correction:
reuse the production measured weapon-path/facing/native-age context for the slash
thumbnail. Haste remains authored sprite layers; registered native VFX retain
their exact source identities and independent integration qualification. Further
native VFX selection/integration will proceed with the user effect by effect.

The slash-preview correction is qualified with the real Amber window-break
critical attack:45 native checks across four camera quarters and two source ages
match an independently supplied measured-path native reference byte for byte.
The shared helper supplies facing-specific weapon points, clip FPS, contact time,
horizontal scale and native age conversion; missing path data remains an explicit
source error. No VFX import, artwork or selection change is part of this correction.
Evidence: `generated/studio_slash_thumbnail_checks.json`.
