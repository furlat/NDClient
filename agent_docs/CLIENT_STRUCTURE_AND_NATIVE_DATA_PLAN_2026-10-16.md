# Client structure, steady frame and native data plan — 16 October 2026

Status: **final plan** (revision 5, 17 October 2026). Requested by the user
on 16 October 2026: a complete plan to organize the client, isolate
performance culprits, separate Studio from the live game while sharing the
renderer and resources, migrate slow runtime JSON to native Godot Resources,
and make new spells/VFX easy to add. This document makes no production
change. Starting checkpoint: `c2b0bfc` (tested checkpoint, performance
incomplete). Three independent reviews (anti-slop, plan adherence,
correctness/anti-OOP) were applied in revisions 2–4; revision 5 adds the
user's later directions and the execution gate (§0, §13).

**Governing rule (user, 17 October): no new Factory content enters the client
until the existing blockers are proven solved (Gate A, §0).**

Relationship to existing documents:

- [Preparation/publication plan](PREPARATION_PUBLICATION_OWNERSHIP_PLAN_2026-10-15.md):
  its §3 first principles remain binding.
- [Three-operation plan](THREE_OPERATION_CLIENT_COMPLETION_PLAN_2026-10-16.md):
  remains the controlling design. This plan's frame work (§5.5, Phase 1) is
  the completion of its **Operation 3** (lines 209–238), not new scope; Track R
  continues Operations 1–2.
- [Performance handoff](CLIENT_PREPARATION_PERFORMANCE_HANDOFF_2026-10-16.md):
  evidence, rejected approaches and the three next reveal boundaries.

This plan adds what those documents do not cover: separating the live game
from Studio, the runtime JSON boundary, and spell/VFX extensibility. It also
sequences the reveal work so structural and performance edits do not collide.

## 0. Execution order and the blocker gate

**Stage 1 — prove the existing blockers solved.** First, and with priority
over everything else:

1. Phase 0 — benchmarks and baselines.
2. Phase 1 — delete repeated per-frame work; attribute and fix the targeting-
   mark and shadow-plane spikes.
3. Track R — the three reveal boundaries (door/movement holds, publication,
   opening handoff), with Phases 4 and 5 where Track R needs them.
4. Track N step 1 — cheap runtime deletions (deep copy, schema parses,
   freshness scan, scene-thread reads).

**Gate A — blockers solved.** All of the following hold on the median of
three consecutive live Gallery routes, and on the §8 benchmarks:

- door and movement media + world hold below 100 ms each (user minimum; the
  target remains below 50 ms);
- steady frame (idle and animating) median at or below 10 ms;
- no frame interval above 16.7 ms without a recorded cause, and none caused by
  repeated per-frame work;
- every §9 gate green.

The gate moves only by the user's decision (D7), never because a stage ran
long.

**Stage 2 — structure without new visuals.** May start after Phase 1, never
competes with Stage 1 for the same files (§9 sequencing table), and yields to
Stage 1 when both need an owner: Phases 2, 3, 6 and 7; Track N steps 2–4;
Track S steps 1–6, which convert **existing** content to native resources with
exact visual parity and delete the legacy runtime paths. Nothing on screen
changes in Stage 2.

**Stage 3 — new content, only after Gate A.** The Factory's 17 October
delivery (89 selected IDs, 15 condition markers) and later deliveries enter as
candidate cues: one pilot batch (Haste plus two or three condition effects),
then batches of about ten, each gated by the benchmarks and the user's visual
acceptance. Track S step 7 (porting the Factory's native body treatments)
belongs here.

## 1. Outcome

1. **Two applications, one renderer.** The live game and Studio are separate
   entry scenes. Both instantiate the same renderer script (today's `play.gd`
   with its live-only code removed). Neither carries the other's state, input
   or UI.
2. **Culprits are separable.** Each per-frame and preparation cost has one
   owner and one call site, and can be benchmarked on a fixed recorded input
   without a live server.
3. **Steady frames stop repeating unchanged work.** Owners return early when
   their inputs did not change; readiness checks do no work.
4. **No authoring JSON on the play path where it costs time.** The runtime
   reads native Resources prepared offline wherever the conversion changes the
   data's shape (§6.1). The wire protocol and journals stay JSON.
5. **Adding a spell or a lasting effect is a data change.** Factory content
   (or a registered sprite asset) plus one authored file per spell or
   condition presentation, then the importer and the generic tests. No code
   lists, test constants or importer branches change. Swapping a sprite-sheet
   effect for Factory VFX is a data edit. Artistic acceptance stays a separate,
   explicit user decision.

Baselines from the final route (`20261016T212402.703340Z`; idle numbers from
its `spell_profile_idle_same_view` stage, 225 frames, as recorded in the
handoff and `data/client_preparation_checkpoint_2026-10-16.json`):

| Metric | `c2b0bfc` | Target (source) |
|---|---:|---|
| Idle frame interval, median / p95 | 13.03 / 18.70 ms | ≤ 10 ms steady frame (three-operation plan) |
| Idle Player script CPU, median | 10.31 ms | Estimate only: ≤ 5 ms looks reachable from the skippable idle phases in §3.2 (nested, not additive), which would put the median interval near 7.9 ms given ~2.85 ms of non-script time. Measured in Phase 1. |
| Warm action onset (packet → first animation) | 43.96–115.33 ms | ≤ 30 ms (three-operation plan) |
| Ordinary publication | door 37.9 ms frame | ≤ 1 ms (three-operation plan) |
| Door media + world hold | 14.7 + 295.9 ms | < 50 ms, 100 ms minimum (user) |
| Largest post-onset frame (door / move / Fireball 2) | 37.9 / 52.3 / 29.3 ms | No unattributed interval; no spikes (user) |
| Largest pre-onset frame (move / Fireball 1) | 55.4 / 46.1 ms | Same |
| New spell: hand-edited code/test/registry files | ~10 | 0 (one authored file per spell plus Factory content) |

This plan does not claim to meet the hold, onset and spike targets alone. It
removes the steady overhead every frame pays and makes the remaining work
attributable.

## 2. Constraints carried forward

The user's recorded corrections and existing plan limits govern every phase:

- No backend, Factory or engine edits. Factory files may be **read** as import
  inputs.
- Preserve approved output: Forward+/Vulkan, source sampling and pixel
  density, authored clocks, tint/material treatment, 2D normal lighting and
  cap, shadows, wall modes, depth/sort conventions, audio, hierarchical event
  order, accepted state/display separation. Every phase keeps the existing
  exact captures byte-identical.
- No local prediction or fabricated events. Preparation may look ahead at
  received operations; it never publishes future state.
- Trust admitted backend payloads and exported artwork. Validation belongs to
  import tools and tests. No runtime schema, hash, freshness or recursive
  validation scans; no recursive freezing; no readiness caches or
  certificates around repeated work — delete the repeated work instead.
- Source identity is the actual layer/category/clip plus admitted authoring
  revision, never actor UUID, item UUID, transform, tint or HP.
- Sharing follows mutability: immutable sources, shaders and prototypes may be
  shared; materials, particles, viewport outputs, clocks, voices and pane state
  stay private.
- One host-frame preparation account for the displayed view, Studio
  candidates, native warming, thumbnails, UI construction and retirement, using
  existing owner queues; no new competing scheduler (Operation 3).
- No new ECS, scheduler, work queue, manager or class hierarchy; no generic
  transaction graph.
- Assets stay ignored and in their current location.
- Rejected by the handoff (line 277) and not proposed as plan steps: "raising
  the 2 ms allowance; dropping source roles or unseen-view state improperly;
  fake speculative events; a new queue or renderer; Node pooling based on an
  inclusive constructor bucket; recursive runtime validators/freezing;
  duplicate source discovery; per-object full visibility scans". D1 asks the
  user whether to reopen one narrow case; it is not a step.
- Measure the whole critical path. A faster leaf is not a result unless the
  player-visible total moves.

**Spell status.** Aid, Bless, False Life and Sacred Flame are not accepted by
the user, and timing and positioning remain unaccepted for **all** spells
(Factory handoff lines 14–23). This plan changes pipelines, not artistic
status. Unaccepted Factory VFX stay review-only candidate cues until the user
accepts them; no step promotes a candidate.

## 3. Evidence at `c2b0bfc`

### 3.1 Final live route (handoff)

| Action | Server dispatch | Packet → first animation | Media / world hold | Largest post-onset frame |
|---|---:|---:|---:|---:|
| Door | 77.8 | 107.1 | 14.7 / 295.9 | 37.9 |
| Movement | 72.2 | 115.3 | 0 / 19.8 | 52.3 |
| Haste | 17.0 | 44.0 | 17.0 / 0 | 30.2 |
| Fireball 1 | 562.0 | 82.9 | 34.1 / 19.7 | 28.9 |
| Fireball 2 | 446.3 | 74.8 | 13.8 / 23.1 | 29.3 |

All milliseconds. Fireball server dispatch is a backend matter, outside scope.

### 3.2 Steady frames are script-bound (new analysis)

Source: `generated/profiles/2026-10-16T23-24-31-gallery-live-spells.json`
(final route, 9,178 frames). Frames classified from the recorded view context
(no queue, no motion, no hold, actors present); the classification script is
committed in Phase 0, and targets are judged by the recorded idle stage above.

| Frame class | Frames | Interval median / p95 | Player script CPU median | GPU median |
|---|---:|---:|---:|---:|
| Idle (classified; includes 43 one-actor frames) | 655 | 12.26 / 20.07 ms | 9.45 ms | 0.14 ms |
| Idle, full scene only (6 actors; median 543 draws, 537 receivers) | 612 | 12.54 ms | 9.64 ms | — |
| Animating | 643 | 12.82 ms | 9.25 ms | 0.14 ms |
| Clock held (waiting for world) | 38 | 7.22 ms | 5.53 ms | 0.05 ms |

The GPU and render thread are nearly idle; the steady frame is per-frame
script work in `play.gd._process`. Idle phase medians (nested, not additive):

| Phase | Median | Cause in code |
|---|---:|---|
| `session_timeline` | 2.51 | Spans `play.gd` ~583–630 and nests `media_publication` (1.29) and `timeline_advance` (0.93, of which `timeline_media_ready` 0.91). `timeline.advance` calls `media_ready` with a fresh empty group every frame (`timeline.gd:292-294`); `_media_ready` runs `component_renderer.prepare` and `_prepare_media`. The existing reuse check misses every idle frame: `_same_resource_groups` compares by identity (`component_renderer.gd:51`) and the empty group is a new `{}` each frame, so `required_components` charges a median 732 µs of the 2 ms account. |
| `native_2d_lighting` | 2.38 | Every frame: `generated_shadows.sync` (1.27); `native_light_atlas.sync` (0.74) rebuilds its moving-entry list from all actor/fixture entries; light projection (0.34) sets every PointLight2D property with no change check (`lighting_2d.gd` `project()`). |
| `optional_preparation` | 2.08 | The optional lane runs with nothing to prepare: media optional maintenance (0.72), retirement, optional components. |
| `media_publication` | 1.28 | `_warm_media(true)` → `_prioritize_media` → `_publish_media_interest` rebuild due/demand sets every frame. |
| `actor_sample` | 0.93 | Persistent spell/blood component sampling (0.48) and pose keys. |
| draw order/output | ~0.8 | `ground_overlay.sync`, actor order keys, `atlas.sync_output`. |

The held-frame row does **not** show headroom: 35 of its 38 frames are the
door's pre-reveal room (frames 7798–7832: 1 actor, 38 draws). The three
full-scene held frames took 14.2, 26.1 and 55.4 ms.

### 3.3 Door reveal critical path (handoff)

- Main-thread reveal preparation **90.7 ms**: actors 13.7, objects 29.0 (of
  which ordinary fixture constructors 12.3 for the 11 ordinary rows; 107
  objects constructed, 96 worker rows), atlas 24.1 (sources 13.1, incident
  capture 3.5, bind 5.9, reserve 1.7), environment capture 4.0, untimed
  "other" 19.8.
- Worker elapsed 208 ms (derive/sort 138, atlas 70), overlapping.
- After the click: construction starts at 316 ms and completes at ~600 ms;
  atlas wait 644–708 ms; publication at 753 ms. World gate 469.5 → 765.4 ms.
  During the gate 35 frames charge 75.5 ms of preparation with 1.5 ms of the
  allowance unused.
- Frontend before the scene thread (handoff line 595): 67.7 / 51.9 / 17.8 /
  30.4 / 24.5 ms for door / move / Haste / Fireball 1 / Fireball 2, plus
  39–63 ms of scene/draw tail.

### 3.4 Publication and pre-onset spikes

| Frame | Interval | Measured cause (handoff) | Outside Player script | Hypothesis from code reading (unverified) |
|---|---:|---|---:|---|
| Movement 7962 publication | 52.3 | Shadows 12.9, of which the `update_light_plane` bundle 10.75 | 8.1 | The bundle (`canvas_shadows.gd` ~575–588) resizes the ground `PlaneMesh` (`ground.mesh.size`), sets two ground material parameters, the light position and `omni_range` on a shadow-casting OmniLight3D. Which call blocks is not known; the handoff requires separating scene calculations from indivisible native calls before assigning a cause. |
| Movement 7933 pre-onset | 55.4 | Light projection 14.1 | 15.8 | Not attributed. |
| Fireball 1 8189 pre-onset | 46.1 | Draw ordering 27.3; inside it `ground_overlay_sync` 27.02, of which `ground_overlay_mark_update` 27.00. No static sort ran. | 9.1 | The targeting-mark update (`ground_overlay.gd` ~395–462) creates and frees one mark Node per raised cell as the area preview sweeps, rebuilds routes, and on any change re-sorts all overlay entries in `_order` with a script comparator. Which of these dominates is not yet timed. |
| Haste 8077 | 30.2 | — | 22.2 | Not attributed. `frame_profile.gd` records pipeline-compilation counters per frame; not yet correlated. |

### 3.5 Single live runs are too noisy to judge a change

Movement hold across consecutive handoff runs: 304 → 400 → 73 → 286 → 1342 →
109 → 15 → 16 → 121 → 0 → 20 ms. Deterministic benchmarks (§8) are therefore
the first deliverable.

## 4. Structural diagnosis

### 4.1 `play.gd` mixes the renderer, the live game and Studio hooks

| Responsibility | Approx. lines | Live | Studio | Sandbox |
|---|---|---|---|---|
| Studio replay bridge, allowance accounting, native startup | 231–297, 453–576 | ✓ | ✓ | partly |
| World boundary candidate preparation and publication (`_sync_world` ~245 lines) | 791–1260 | ✓ | ✓ | bypassed |
| Static views, rotation, global atlas | 1259–1381, 2980–3117 | ✓ | ✓ | |
| Scenery visibility, walls, wall mask, draw order | 1383–1560, 2735–2978, 3594–3695 | ✓ | ✓ | hand-driven |
| Actor membership and sampling | 1567–1753, 2530–2733 | ✓ | ✓ | hand-driven |
| Media coordination | 1755–2528 (~770 lines) | ✓ | ✓ | forced ready |
| Live interaction: choices, preview, commands, receipts, hover, loot, approach, input | 3119–3593, 3697–3895 (~750 lines) | ✓ | never | never |

About 200 member variables, plus about 60 inherited workshop variables, 45
workshop methods and 9 parse-time preloads from `main.gd`. Play overrides
`_ready`, `_process`, `_input`, `_unhandled_input`, `_exit_tree` and
`texture()` without `super`; it uses only `position_camera()`,
`pixel_selected()` and a few texture/row variables from `main.gd`.

### 4.2 Helpers reach back into the host

- `WorldPreparation` reads about 40 host fields and writes `static_entries`,
  `fixture_entries`, `world_groups`, `ground_groups`, the static order and
  `native_light_atlas.prepared_delta` back into the host.
- `ComponentRenderer` reads `world.timeline` 51 times and appends to
  `world.actor_entries`; blood rendering does the same.
- `NativeSpellRenderer` changes `world.camera.cull_mask`.
- `native_light_atlas` writes `world.presentation_errors`.
- Media residency is shared between hosts by weak reference; pruning in one
  instance calls `_release_actor_source` on every other instance.
- `ActorConstruction` takes a host (Play or WorldPreparation) and calls its
  `add_entry`, `texture`, `_light_entry`.

### 4.3 The frame repeats work, and readiness checks do work

- 17 preparation call sites in one frame: `_step_world_preparation` from six,
  `_prepare_future_world` and `_warm_media` from four each,
  `_receive_prepared_operations` from three. Some are genuine same-frame
  re-checks: the second handoff in `_advance_prepared` (`play.gd` ~563–575)
  exists so a cut that finishes mid-frame publishes without an extra frame.
- `_world_ready` and `_media_ready` are called from inside `timeline.advance`
  through injected callables. They create and step a `WorldPreparation`, run
  component preparation, plan media and charge the allowance. `_world_ready`
  also performs **admission** (`admitted = true`), and the Timeline applies the
  plan in the same call (`timeline.gd` ~318–323). `media_ready({})` also
  recomputes `media_initial_ready`, which gates `command_ready()` and the
  missed-outfit error.
- Priority is encoded by call order and comments. The handoff's history shows
  the results: HUD bar pending for over 5 s, source receipt starving the
  world, door improvements regressing movement.

### 4.4 One account, with two fallback exceptions

The shared `preparation_admission` account (2 ms; `PREPARATION_USEC` at
play.gd:105, the account at :106) already receives media uploads
(`"media_upload"`), rotation steps (QuarterView is stepped with the account's
remainder and charged as `"rotation"`), world preparation, global lighting,
HUD bar construction and Studio thumbnails. MediaWarmup's per-frame image count
and the process-wide one-native-mutation-per-frame gate are inner bounds inside
that account. The exceptions are two fallbacks used only when no account is
passed: `component_renderer._native_budget` (component_renderer.gd:82) and
`blood._prepare_budget` (blood_renderer.gd:23). Operation 3 requires one
account; Phase 1 deletes the two fallbacks.

### 4.5 Modes are flags, not applications

- 36 `external_playback` branches plus `external_clock` in play.gd; two
  `host.external_playback` reads in `world_preparation.gd`.
- `sandbox/world.gd` extends play.gd, replaces `_process`, writes
  `timeline.state` directly, forces `media_initial_ready`, overrides
  `texture()` with synchronous disk reads, and loads `res://tests/...` scripts
  from production code through 14 command-line flags.
- Each Studio pane is a full Play: it allocates a PopupMenu and
  `selection_media` and connects a `frame_post_draw` callback that runs every
  frame even for frozen panes.
- Studio's spell-hit-material toggle persists to the same
  `user://rendering_settings.cfg` the live game reads.

### 4.6 Two code paths for the same publication

`_sync_world` keeps a synchronous rebuild beside the prepared path. Scenery
and draw order each have "trusted proof" and "recompute" branches. Not every
second path is a dead fallback:

- `Characters.resolve` is a **production** path: it runs in live play whenever
  `timeline.revision` changes and no prepared owner exists (`play.gd` ~1631,
  ~1650–1655); the final profile shows resolved rows in 10 live frames.
- `Delta.reconcile` is the live code that applies `prepared_delta`
  (`native_light_delta.gd` ~1378–1663). Only its `_fallback` branches and the
  full planner `_reconcile` (`native_light_atlas.gd` ~1412) are fallbacks; in
  live play `require_prepared_publication` already turns them into a hard
  failure.
- `_reconcile_actor_layers` is used by the sandbox, which calls
  `_sync_actors()` with `world_prepare_epoch = -1` (`sandbox/world.gd` ~190,
  ~271, ~450).

Each deletion must first list its remaining callers (Phase 4).

### 4.7 Process-wide static state

`NativeStartup._state` (adds a warmup SubViewport under the tree root),
`NativeSourceAdmission`, `NativeSourceResources.programs`,
`NativeFactorySource._prepared_packets`, `BodySources._current`,
`NativePresentationSources._current`, `NativeParticleUnits`,
`BloodRenderer._programs_prepared`, `SourceMaterial.declared_parameters`:
shared by every Play in the process, some unbounded (§7.2).

## 5. Target structure

### 5.1 Layout

One Godot project with separate entry scenes (decision D4). No mass directory
relocation: renderer code stays in `presentation/`, Studio in `studio/`, the
sandbox in `sandbox/`.

- `play.gd` loses its live-only code (Phase 3) and its mode flags (Phase 6),
  then is renamed to `presentation/world_view.gd` (keeping its `.uid`). There
  is no wrapper or facade: the renamed script **is** the shared renderer.
- New live-only scripts go in `live/`: `live_game.gd`/`live_game.tscn`
  (composes the renderer, Session, interaction, HUD), the interaction code
  extracted in Phase 3, and `play_hud.gd`.
- `project.godot`'s main scene becomes `live/live_game.tscn`; `play.cmd`
  launches it; `studio.cmd` and `spell-sandbox.cmd` keep their scenes.
- One small test enforces the separation: `presentation/`, `sdk/` and
  `source_catalog.gd` must not reference `live/`, `studio/`, `sandbox/` or
  `tests/` in `preload`/`load`. It is the only automated guard for the user's
  separation requirement.

### 5.2 Ownership

| Owner | Owns | Must not own |
|---|---|---|
| Renderer (`world_view.gd`, one per viewport) | Camera rig, static views, actor visuals, atlas viewport, light nodes, shadows, effects, wall mode, draw order, picking queries, private materials, media coordination for its view | Session, choices, commands, HUD, recording seek, settings persistence |
| Playback configuration (passive record, §5.4) | Which clock owner, which media-plan source, forecast permission, native startup plan, facing default | Any Node or computation |
| Live game (`live/`) | Session, choices, previews, commands, receipts, hover, approach, storage, selection-media hints, native choice resources, input, HUD, live settings file section | Renderer internals |
| Studio (`studio/`) | Recording index, seek, panes, timeline UI, comparison, thumbnails, Studio settings section | Live session state |
| Process-wide caches (existing statics and the physical media owner) | Immutable shared sources, residency, compiled programs, Factory prototypes, the one shared preparation account | Per-view state; unbounded growth (§7.3) |

### 5.3 Renderer surface used by the apps

Derived from what Studio, the sandbox and the live game call today. These are
the renderer's public functions after Phases 3 and 6, not a new layer.

- Playback: `install_playback(timeline, config)`, `playback_prepared()`,
  `can_publish_replay_advance(plan)`, `publish_replay_advance(plan)`,
  `step_native_startup()` (today private `_step_native_startup`, called by
  Studio), native startup status.
- View: `request_view(quarter)`, `rotation_pending()`, wall mode, grid
  visibility, camera focus and size, `position_camera()`.
- Render options: `apply_options(options)` for light profile, strength,
  flicker, cap, normals, spell hit material. **No persistence**; each app owns
  its settings section (Studio stops writing the live game's settings).
- Queries for the live app: `pick_world`, `pick_cell`, `pick_actor`, identity
  hit, route preview (today `ground_overlay.set_preview` from
  `play_hud.gd:1253`).
- Read-only inspection: visual actors, displayed components, playbacks, audio
  diagnostics, light sources, atlas diagnostics, `presentation_errors`,
  `media_issue`.
- Signals: `presentation_updated`; publication failure.

Live-only members leave the renderer completely: `session`, `game_config`,
`hud`, `context_menu`, `selection_media` and its refresh/budget,
`available_actions` and all choice/selection/command/receipt state,
`force_attack`, attack preferences, approach, storage/loot, hover, cursor,
`_discover`, `_poll_actions`, `_submit`, input handlers, `notice_text`,
`error_report`, `--config`/`--recording` parsing.

### 5.4 Playback configuration: one passive record

The 36 `external_playback` branches and `external_clock` become reads of one
record passed at `install_playback`. No subclasses.

| Field | Live | Studio | Sandbox |
|---|---|---|---|
| `clock_owner` | renderer | Studio transport or renderer | fixture |
| `media_plans` | derived per group | recorded `group_plans` | fixture loader (today's synchronous `texture()` override, made an explicit callable) |
| `native_startup_plan` | selection + queued groups (callable from the live app) | recorded plan | fixture plan |
| `allow_static_forecast` | true | false | false |
| `facing_default` | actor row | `"SW"` (today `world_preparation.gd:970`, `:1332`, `play.gd` ~2555) | fixture |
| `retire_group` | `session.retire_group` | none | none |

The sandbox stops writing `timeline.state` directly and uses an explicit
state-injection function on the renderer; its check flags move into `tests/`
runners.

### 5.5 Frame: delete repeated work, keep the one account

This completes Operation 3 of the three-operation plan. The 2 ms account and
its priority order stay exactly as they are.

1. **Fix the reuse check that already exists, first.** The idle frame's
   `required_components` cost comes from a reuse check that can never hit:
   the timeline passes a fresh `{}` each frame and `_same_resource_groups`
   compares by identity. Pass a stable empty group (or treat two empty groups
   as the same) — likely a one-line change, no new cache. Measure before
   anything else in this list.
2. **Fewer call sites, without adding frames.** Delete preparation call sites
   that repeat work already done earlier in the same frame. Keep, and
   document, each call site that is a same-frame re-check (for example the
   second handoff in `_advance_prepared`); a call site is deleted only if the
   boundary benchmark shows no added frame. Operation 3's rule holds: when
   opening resources are ready, handoff, admission, readiness and publication
   complete in the same frame; only real barriers yield.
3. **Readiness keeps admission, loses incidental work.** `_world_ready` keeps
   explicit admission in the same call that applies the plan; candidate
   creation stays in `_prepare_future_world`, which already runs earlier in
   the frame. `_media_ready` keeps its side effects that other code depends on
   (`media_initial_ready`, which gates `command_ready()` and the missed-outfit
   error). Required component and media preparation move out of the readiness
   calls only where the boundary benchmark shows no added frame. No cached
   readiness.
4. **Owners return early on unchanged inputs.** Light projection, shadows,
   atlas sync, media demand, optional maintenance and retirement each keep
   their own last-seen revision and return when it is unchanged, following
   the existing `light_revision` / `wall_visibility_revision` pattern. There is
   no central input collection. Rules for the inputs:
   - Display time advances every idle frame, so it is never part of a skip
     key; time-dependent owners use a valid-until horizon, as
     `_next_resource_cue_ms` already does (`component_renderer.gd` ~203).
   - Media readiness depends on residency, which has no revision today
     (`MediaWarmup.ready` reads `ready_paths` directly). Skipping a readiness
     recomputation requires a residency revision bumped on upload, eviction,
     pin change and cross-host release, plus native startup/admission
     progress.
   - Light projection must include fixture energies when fire flicker is on
     (off by default, `render_settings.gd:5`).
   - Clocked owners (moving actors, fixtures, water, persistent effects) still
     sample when display time advances.
5. **Held-frame attribution from existing state.** On held frames the frame
   profile records the existing `media_gate` booleans,
   `timeline.waiting_for_world` and the existing `phase_usec` of the current
   candidate. No new accounting structure.
6. **One account.** Delete the `_native_budget` and `_prepare_budget`
   fallbacks by always passing the account. Studio panes and thumbnails keep
   sharing that one 2 ms account, as today; there are no per-pane allowances.

### 5.6 Typed records: deferred

Converting string-keyed dictionaries (entries, visual actors, candidates) to
typed records is deferred until a benchmark shows dictionary access as a top
cost in an owner. No compatibility shims are planned for it.

## 6. Native data boundary: runtime JSON → native Resources

### 6.1 Rules (from the measured migrations)

- **The format alone is not the win.** A Dictionary-tree `.res` loads at about
  the same rate per byte as JSON (blood asset: 314 KB `.res` → 6.44 ms first
  load; three-operation plan line 591). The past wins came from loading one
  record lazily, sharing one loaded copy across threads (`ResourceLoader`
  `CACHE_MODE_REUSE`), and deleting runtime joins (body sources: actor
  derivation 47.98 → 3.35 ms).
- **A conversion is allowed only if it changes shape:** lazy per-record load
  from a monolithic file, typed packed arrays replacing parsed numbers, or a
  deleted runtime join, scan or duplicate copy. No Dictionary-tree `.res`
  wrappers. Data read once off the critical path moves to a worker instead.
- One Resource per record behind one index Resource with a `current` revision
  marker, as body sources and native spells already do.
- Numbers in typed packed arrays (`PackedInt32Array`, `PackedFloat64Array`,
  `PackedVector2Array`); never `PackedFloat32Array` for authored values.
- `.res`, not `.tres`, for float data (the `.tres` fixture optics failed exact
  qualification on round-off).
- Godot's `JSON.parse_string` returns every number as a float. Typed int
  fields change `typeof`, `==` and `str()`; keep floats or prove consumer
  parity in the importer's tests.
- Shared REUSE Resources are never mutated. No recursive freeze.
- Validation runs in the importer and tests only.
- `.derived/` is not in Git. A missing `current` marker must fail loudly at
  startup, never resolve to empty recipes (today `native_spell_authoring.gd:9`
  returns `{}` for every spell, including the body cast animation).

### 6.2 Candidates

Sources for "measured" cells: the final route profile
(`generated/profiles/2026-10-16T23-24-31-gallery-live-spells.json`, frames
7682 and 7932) and the compiler audit
(`.runtime/compiler-audit-leaves-20261016/result.json`). Both are ignored local
files; Phase 0 re-measures every candidate before work starts. "est." is an
estimate from the measured parse rate of about 7–20 ms per MB and never
justifies a conversion on its own.

| # | Runtime JSON | Size | Read where / thread | Cost | Shape change |
|---|---|---:|---|---|---|
| N1 | `catalog/attack_recipes.json` | 6.29 MB, 5 recipes; `weaponTrail` copied 4× | `authoring.gd:54-55`, `event_trace.gd:223`; session preparer on first weapon attack | est. 45–125 ms cold (not in the Gallery route) | **First** delete the per-call `recipes[key].duplicate(true)` in `Authoring.attack`. Then one recipe `.res` per behavior plus one shared trail Resource with `PackedVector2Array` per facing (deletes the 4× copy). |
| N2 | `assets.json` | 3.69 MB, 1,395 resources | `source_catalog.gd` ~444/495/521, `environment_media.gd`, `world_preparation.gd` ~282; first media plan worker; per-frame lookup in `_sample_fixtures` | Measured (frame 7682): first required plan metadata 138 ms = characters 54.2 + environment 83.1, the latter including an 80.8 ms initial update. assets.json's share est. 40–70 ms. | Per-record lazy asset index |
| N3 | `environment/banks/**` | 324 files, 66.5 MB (intact ~10 KB, break banks up to 1.26 MB) | `source_catalog.gd` ~187; compile, plans, selection | Measured (compiler audit): Fireball 2 break bank 376 KB → 6.1 ms; door's 15 intact banks inside a 24.7 ms cold compile parse | Rects/frames as `PackedInt32Array` |
| N4 | `media/definitions` + `media/storage` | 2,107 files, 36.7 MB | `registered_media.gd:5-23` via `conditions.gd`; per-condition compile | Measured (compiler audit): Haste 2.6 ms parse + 0.8 ms read for 8 documents | One record per asset joining definition + storage (deletes the runtime join and path walk) |
| N5 | Condition/action recipes + `NativeAuthoring.overlay` | `condition_recipes` 572 KB + others | `native_authoring.gd:36-160`; compile | Measured (compiler audit): overlay cold 6.99 ms on the door | Full per-behavior import into the existing `catalog.tres` classes (deletes the JSON + overlay join and the runtime `_range` checks) |
| N6 | `generated/environment_receiving_normals.json` + texture layouts | 596 KB + 19 KB | `source_catalog.gd` ~353-414; plan worker | est. 6–12 ms, inside the first plan | Only if measured on the critical path: per-path records |
| N7 | UI catalog: `ui/presentation.json`, `resources.json`, `choices.json` | 539 KB | `ui_catalog.gd:9-14`; **scene thread**, first HUD paint | est. 5–11 ms | Move the read to a worker before first paint (no format change) |
| N8 | Startup documents: `catalog-index.json`, `catalog/resources.json`, `rig.json`, `world.json` | ~808 KB | `play.gd` `_ready`; **scene thread** | est. 8–16 ms | Move the read to a worker before first frame (no format change) |
| N9 | `native_effects/index.json` | 249 KB; its `spells` part is superseded by `.derived/native-spells`; parsed twice under two cache keys (`Authoring.load_data` from `components.gd:113, 168-169` and `native_effects.gd:5, 34-38`) | `components.gd`, `conditions.gd`, `native_persistent.gd:47` (scans it), `movement_media.gd`, `event_trace.gd` | est. 2.5–5 ms | Merged into the spell index (Track S); deletes the double parse and the scan |
| N10 | `schemas/animation.schema.json` | 213 KB, read for **one default value** | `authoring.gd:19-21`; first movement compile | est. ~6 ms of movement's 7.3 ms compile parse | One scalar on `catalog.tres` |
| N11 | `.derived/palette-ranges/*.json` | 9 files | `palette.gd:6-58`; compile worker; mtime/size freshness check per call, a miss decodes the whole PNG | Runtime freshness scan (forbidden by the constraints) | Baked into body-source layer records; deletes the scan |
| N12 | Environment PNG header reads (not JSON) | — | `encounter_media.gd:176-186`; optional estimates phase | Measured: up to 33.4 ms in one frame (frame 7932) | Dimensions stored in the asset index; deletes file inspection |
| N13 | Protocol schema `player-api-v1.schema.json` | 512 KB, parsed by the GDScript StrictJSON parser in every `Protocol.new()` | Session creation on the **scene thread** (`session.gd:15`, and the session's Journal at `journal.gd:5`); a third parse on the transport thread (`transport.gd:745`) | Not measured; startup only. Time `Protocol.new()` first. A fourth parse site is `studio/recording.gd:63`. | Stays JSON (it is the contract). Parse the schema and identity dictionaries once, before the transport thread starts, and share **only those parsed dictionaries**: each Protocol object keeps its own mutable caches (`_patterns`, `_producer_json`, envelopes). Deletes two of three live parses. |

Open question outside this plan: `protocol.gd` still runs `_validate_schema`
at runtime for non-trusted roots. That conflicts with "trust admitted
payloads" and should be decided separately.

Workshop/exploration-only data (`library_sequences.json`, `unity_sources.json`,
`unity_map.json` 32.7 MB) is out of the play path and stays as is.

### 6.3 Keep as JSON

- SSE packets, journals and recordings: wire contract and durable records.
  Their parse cost (door 21.5 ms on the transport thread) belongs to the
  protocol.
- Offline import inputs (Factory delivery manifests and selection receipts,
  body source descriptors), test oracles,
  `--config`, workshop saves.
- Studio tooling that runs on its own thread or once at Studio start.
- External `.media` JSON: no Godot script reads it.

## 7. Spells and VFX: make extension a data change

### 7.1 Today

Path: Factory JSON recipes (132) → `tools/prepare_projectile_sandbox.py`
(copies closures, regex-patches adapter sources, writes the 258 KB
`authoring/sandbox/projectiles.json`) → `tools/native_spell_light_intake.gd`
(writes `source_bounds` into the hand-authored
`authoring/native_effects/index.json`) → `tools/bake_native_source_variants.gd`
(variant `.res` packets) → `tools/import_native_spells.gd`
(`.derived/native-spells/<rev>/<id>.res` + `index.res` + `current`).

At runtime `compiler.gd` maps `SpellFact.behavior_id` through
`native_spell_authoring.gd` to `NativePresentationSources.find`. A spell not
in the index falls back to its older hand-authored draft
`authoring/spells/spell.<id>.json` (`native_spell_authoring.gd:10` →
`authoring.gd:47-52`). This is how the four deferred spells render today: the
draft supplies the caster's cast animation (body clip, release frame, weapon
glow, sockets) and condition placement; the buffs then show through the
separate condition visuals; Sacred Flame's draft also supplies its older 2D
flame media at the target (`cantrip.sacred_flame.back/front`) and a hit flash.
No Factory VFX plays for these spells. An explicit missing
status also exists (`native_spell_authoring.gd` ~38-40, `status:"missing"`,
`native_source_not_imported`).

Counts: 149 spell drafts (127 `spell.*` plus 22 option/action variants), 34
capabilities / 78 clips in the manifest, 30 active in production plus 13 asset
metadata entries, 4 deferred. One spell has an audio binding. 12 of 16
damaging spells have native body-material hits.

**Adding spell N+1 today touches about ten hand-maintained places:** the
spell draft; staging or batch entries; a sandbox `.tres`; the
`index.json:/spells` entry; optional body-material, casting and audio files;
**adapter lists** in `native_source_variants.gd:14-38` (a missing entry
silently takes the slow unprepared path) and sometimes `_program_policy` in
`native_factory_source.gd`; the Studio capture script's family/case tables;
test constants (`native_spell_batch_authoring_checks.gd:19-20` expects exactly
30 and the deferred list, `studio_spell_batch_checks.gd`,
`sandbox_batch_checks.gd:47` expects 20, `live_spell_checks.gd`,
`native_spell_retained_tail_checks.gd`, `native_spell_library_checks.gd`); and
counts in docs.

Runtime presentation code has essentially no spell-id branches. Spell-specific
code lives in the tools: importer fixes for ice_knife, sleep, fireball, web,
poison_spray, scorching_ray and produce_flame; bake-time branches for
thunderwave and sanctuary; a hard-coded magic_missile case in
`studio/case_library.gd`.

The runtime spell Resource (`presentation/resources/native_spell.gd`) exports
untyped `selection/recipe/hit: Dictionary` fields: JSON wrapped in a Resource
(`lifecycle.cue_ids` arrive as floats and are cast at runtime).

**Factory production handoff, 17 October**
(`VFXFactory/docs/NATIVE_VFX_PRODUCTION_HANDOFF_2026-10-17.md`). The Factory
designates its editable `.tres` Resources as the production format:
`SpellResource` (`factory/authoring/spell.gd`, `to_selection()`, `validate()`)
and `PhaseResource` (`factory/authoring/phase.gd`). The delivery overlay
`authoring/delivery/native-production-20261017/resources.json` selects 89
resource/scenario IDs (not spell counts), with selection receipts; 36 of 232
original-library findings remain open. Its seven validation checks are
headless resource/contract checks, not optical qualification; the summary
records `production_integration_performed: false` and
`human_approval_inferred: false`. The Factory's contract for importing:

- Carry the `.tres` dependency closure **plus** the referenced `factory/`
  constructors, helpers and shaders and their donor geometry/textures.
  Constructors load explicit string paths, so a `.tres`-only dependency scan
  is not enough. Keep the `res://factory/` namespace or rewrite it once at
  import. Preserve license/purchase provenance; do not copy the purchase
  archive, review videos, `.godot` cache or old sprite banks.
- Keep versioned phase paths; never substitute an older constructor by name.
- Each occurrence (including each admitted recipient) has its own `cue.id`;
  `SpellResource.validate()` rejects duplicates.
- Bind `opacity_uniform` on the phase option or cue, not the component option.
- Keep source clocks, seeds and per-phase `simulation_hz` (evidence ran at
  144 Hz physics); do not force 60 Hz or replace sustained loops with fixed
  leases. Seeking stateful rigid-body/GPU sources still needs its own contract.
- Preserve sampler defaults, masks and alpha/additive treatment
  (`SourceMaterials`); keep body receiver-family classification
  (`ActorMaterialAtlas`); `SourceFinishPass` is per selection.
- The Factory's copies of `native_factory_source.gd`,
  `native_spell_playback.gd` and `choreography.gd` are pinned reference seams:
  port the needed adapter changes into the current client renderer; do not
  replace newer client code with the snapshot.

This supersedes the earlier assumption in this plan that Factory `.tres`
cannot load in the client: the import carries the Factory's script closure.
Factory JSON recipes are no longer needed as an input.

### 7.2 What does not scale

| Item | Measured / found | Growth |
|---|---|---|
| Full-catalog warmup (`.runtime/native-source-startup-all-checks.json`, 15 Oct, before `c2b0bfc`; 72 sources / 30 spells) | 6.55 s, static memory +100 MiB, VRAM +466 MiB, 1,554 material owners, 193 surface + 127 specialization pipelines | Averages ~218 ms and ~15 MiB VRAM per spell, including shared pipelines, so linear scaling overstates the cost. Re-measure at the checkpoint before using it. |
| `NativeStartup._state` (known/plan/done/material owners) | Grows until `reset()` | Unbounded |
| `NativeFactorySource._prepared_packets` | No bound; keeps a PackedScene and materials per admitted component | Unbounded |
| `NativeSourceResources.programs` | LRU of 256 | Evictions cause runtime shader recompiles |
| Distinct palette/finish profiles at once | 12 (`native_spell_renderer.gd:12-13`; capacity message at :228) | "Capacity exceeded" with many ramps |
| Variant bake | Whole manifest under one 180 s deadline (`bake_native_source_variants.gd:12`), ~157 ms per packet | Deadline at ~1,100 components |
| Import revisions / stale variants | Never deleted (10 revision directories under `.derived/native-spells`; 159 packets for 70 live) | Disk growth |
| Studio previews | ~10 MB per spell, 301 MB today | Linear |
| `components.native_phase` | Loops all index sources, `load_data` twice per iteration | Linear per lookup |

Live play requests only the selected spell and queued groups, so the
full-catalog cost is not paid in the Gallery route. The static caches still
grow with everything ever admitted.

### 7.3 Target

**Authored input (offline, Git-tracked), one per spell:**
`authoring/spells/presentation/<id>.tres` holding only hand-chosen fields:
delivery (scope, roles, per-effect overrides), lifecycle (owner kind, owner
ids, integer cue windows), **production cues** (what players see) and optional
**candidate cues** (Factory VFX awaiting acceptance, shown only in Studio and
the sandbox; promoted to production cues only on the user's artistic
acceptance), clip overrides (replacing per-spell
importer code), optional body-material selection, audio cue references, and
the Studio capture profile (targeting kind, area, concentration, follow-up
steps). The capture profile stays in this input; it never enters runtime data.
The importer discovers these files by folder; there is no separate
hand-maintained index. The first import must reproduce today's client-approved
selection, timing, palette and deferrals exactly (three-operation plan lines
256–258).

**Derived runtime data (`.derived/`, generated):** the existing
`.derived/native-spells/<rev>/` package and `current` marker, with the
runtime spell Resource changed from Dictionary exports to typed fields and one
typed cue type (role, integer windows, variant packet reference, source bounds,
lights, finish profile). The index also carries condition-owner and
spatial-owner maps (replacing the JSON scan in `native_persistent.gd`) and
asset metadata, absorbing `native_effects/index.json` (N9). Every spell enters
the index with its production cues; candidate cues are imported for Studio and
the sandbox only.

**One importer**, runnable for one spell (`--only=<id>`) or all:

- Reads the Factory delivery manifest and selection receipts (read-only) and
  copies the selected `.tres` closure with its `factory/` scripts and donor
  assets (§7.1). It runs `SpellResource.validate()` / `PhaseResource.validate()`
  at import only, never at runtime, and records the Factory delivery and
  revision in the derived package.
- Replaces the four current tools for the spell path; deletes stale revisions
  and stale variant packets after a successful run.
- Adapters declare their prepared-state capability in the adapter script,
  replacing the hard-coded lists in `native_source_variants.gd`.
- **Import-time errors, never runtime checks:** unresolved clip ids; roles
  outside the allowed set; cue indices out of range or non-integer; missing
  variant packet; unsupported adapter; missing opacity uniform; owner ids not
  matching the server definition reference; finish-profile count beyond the
  renderer limit; offline-only fields in runtime data.
- Variant bake deadline per item, not per run.

**Runtime:** load the index, then each spell lazily; no JSON, no legacy
fallback. A missing `current` marker fails loudly. Every spell is imported:
those without accepted Factory VFX (the four deferred spells and the 97
draft-only spells) are imported with their current look as native cues (§7.4),
so deleting the fallback changes nothing on screen (D6, resolved).

**Warmup and caches** (decision D5): warm only what can play soon — the
controlled actors' offered spells (from choices) plus spells in received
lookahead operations, as today. Bound `_prepared_packets` and startup material
owners to that scope with release on scope change; size `programs` from
measured counts. Warm pipelines only where the recorded pipeline-compilation
counters show a first-use compile.

**Adding a spell after this plan:**

1. Author it in the Factory (outside this repo).
2. Add `spell.<id>.json` cast data (until the cast recipe also moves) and one
   `authoring/spells/presentation/<id>.tres` with the new Factory VFX as
   candidate cues.
3. Run the importer for that spell; it fails with a specific message if
   anything is missing.
4. Run the generic spell tests; they iterate the index. Optionally record a
   Studio case and bake its preview for review.
5. After the user accepts it artistically, move the candidate cues to
   production cues and re-import.

### 7.4 Not only native spells: drafts, sprite sheets and conditions

The Factory VFX path covers only part of what players see (counts at
`c2b0bfc`, from `authoring/native_effects/index.json`, `authoring/spells/`,
`authoring/catalog/condition_media.json` and `authoring/media/definitions/`):

| Presentation kind | Scope today | Example |
|---|---|---|
| Native Factory VFX | 30 spells in the native index | Fireball, Magic Missile, Shield of Faith |
| Old hand-authored spell draft only (cast animation, condition placement; no Factory VFX) | 97 of 127 `spell.*` drafts; 36 of them also carry 2D sprite-sheet effects | Haste (draft supplies only the cast animation); Sunbeam, Flame Strike, Heal, Cone of Cold, Misty Step, Sacred Flame (sprite effects) |
| Registered 2D sprite sheets for lasting effects | All 236 condition media entries; 1,055 sprite definitions in total (walls 280, persistent 114, support 72, liquid 72, control 63, class 54, curse 40, surface 38, pending 36, weather 35, …) | Haste's buff: looping `pending.haste.back/front` and `pending.haste_feet.back/front`; overhead markers (prone, frightened, bane); class mantles; blinded/control effects |

Ten native spells' drafts also carry 2D media fields; which source wins for
each is checked in Track S step 1, not assumed here.

**Body and animation treatments.** Many conditions were authored in Pygame as
treatments of the actor's own body and animation, not as effects drawn on top.
Neither sprite sheets nor Factory VFX can replace these; they are renderer
features. Counts from `authoring/catalog/condition_recipes.json` (160
recipes); Godot status from `presentation/condition_coverage.gd` ~220–245 and
the [Pygame feedback parity audit](PYGAME_FEEDBACK_PARITY_AUDIT_2026-10-15.md)
(F02–F17):

| Treatment (authored field) | Conditions | Godot today |
|---|---|---|
| Body colour (`bodyColor`) | 9: Haste, Haste lethargy, poisoned, invisible, Invisibility, Greater Invisibility, Power Word Stun, raging, frenzied | Implemented (F03) |
| Opacity (`alphaMultiplier`) | 3: invisible, Invisibility, Greater Invisibility | Implemented without the eased 240/200 ms application/removal transition (F02) |
| Resting pose and fall/rise (`bodyPose`, application/removal `bodyAnimation`) | 3: prone, Sleep, Eyebite asleep | Implemented; overlapping-rest risk (F05, F06) |
| Frozen pose (`frozenPose`) | 2: paralyzed, petrified | Fixed frame implemented; petrified's captured current pose missing (F04, F10) |
| Outline (`bodyOutline`) | 1: paralyzed | Implemented (F04) |
| Body material ramp (`bodyRamp`) | 5: raging, frenzied, petrified, Barkskin, Stoneskin | Only the flowing-film mapping (rage/frenzy); stone, bark and Stoneskin missing (F11, F12) |
| Weapon/item materials (`equipmentModifiers`) | 5: Shillelagh, four weapon coatings | Missing (F14) |
| Attached appearance layers (`appearanceLayers`) | 2: Fly, Dragon Wings | Missing |
| Body distortion and trails (`bodyDistortion`) | 1: Blur | Missing (F13) |
| Body and socket scale (`bodyScale`) | 1: Enlarge/Reduce | Missing (F15) |
| Live body copies (`liveCopies`) | 1: Mirror Image | Missing (F16) |
| Absence echo (`absenceEcho`) | 1: Banishment | Missing (F17) |
| Application/removal effects | 7 / 8 (Command, Bestow Curse, Blur, Enlarge/Reduce, charmed, …) | Per effect |

So a condition's presentation has three kinds of cues: **effect cues**
(sprite sheet or Factory VFX, swappable as data), **body cues** (pose, frozen
or captured pose, colour, opacity, outline, material ramp, distortion, scale,
copies, absence echo, item material, appearance layers), and **markers**. The
authored cue model, the importer and the parity gates cover all three. Body
cues are implemented once in the renderer and selected by data; adding a
condition that reuses an existing body cue is a data change, while a new kind
of body cue is renderer work.

**Factory condition delivery, 17 October.** Sources:
`VFXFactory/docs/CONDITION_VFX_COMPLETE_INVENTORY_2026-10-17.md`,
`PYGAME_CONDITION_BEHAVIOR_HANDOFF_2026-10-17.md`,
`authoring/conditions/resources.json` and `authoring/conditions/bindings.json`
in the Factory. Effects and markers will be 3D native, not sprite sheets.

- **Markers:** 15 standalone native marker Resources cover 25 condition
  identities through explicit aliases in `bindings.json` (for example one
  frightened marker for frightened, Fear and Eyebite panicked; one paralyzed
  marker for paralyzed, Hold Person and Hold Monster; Reduce only when
  `size_change=reduce`). Use these bindings; never infer a condition from a
  spell name.
- **Embedded phases** inside other selections: blinded, charmed, deafened,
  stunned, Sleep/Eyebite asleep, Power Word Stun, Silence deafened, Sunbeam and
  Sunburst blinded. Use the phase Resource; never replay a whole spell to show
  its condition.
- **Composition sources** (native spell exists, condition adapter not
  certified): Haste, Invisibility, Greater Invisibility, Stoneskin, Bestow
  Curse, Beacon of Hope, Death Ward, Enhance Ability, area zones and others.
- **Native body-treatment components** exist in the Factory for petrified
  (material plus pose capture), Barkskin, Stoneskin, Rage/Frenzy film,
  invisibility (`ActorRuntime`), Blur, Mirror Image, Banishment, Shillelagh and
  Fly wings. They are reference implementations running in the Factory's copy
  of the renderer; the client ports them as body cues. This settles the earlier
  stone/bark/Stoneskin question in favour of the Factory components.
- **No native resource yet** (inventory "legacy"): Aid, Bless, Guidance, Light,
  Mage Armor, Resistance, Sanctuary, Shield, Shield of Faith, Protection from
  Energy, Longstrider, Darkvision, See Invisibility, True Seeing, Fire Shield,
  Sunbeam, Harm, general restrained, Web restrained, no reactions, no healing,
  life drain, field focus, jaw restrained, Eyebite casting, False Life record,
  Rage/Frenzy class records (whose Film adapter exists separately), reckless
  attacking, elemental affinity, metamagic. Several are created by the 30
  production spells (Shield of Faith, Guidance, Resistance, Light, Sanctuary,
  Mage Armor, Shield, no healing, no reactions). They keep their converted
  current look (sprite cues) until a native port is accepted.

Integration rules from the Factory, all client work:

- Feed native markers through the existing 1,800 ms semantic marker playlist
  in `conditions.gd`; do not start one loop per marker.
- The 13 older marker roots carry an internal 3.2 s envelope and a fixed local
  height. Replace the envelope with the actual owner's hold and removal, and
  resolve real head clearance (the Guiding and Pause markers show the
  attached-overhead path).
- Keep Bane's rotating body effect and Charmed's body hearts; the marker is
  added, not substituted. Slow and reduced movement have different symbols;
  Unconscious is not Sleep's Zzz; paralyzed does not imply Hold's chains.
- Body, equipment, marker and spell are separate channels with their own
  owners and tails. A cure removes only its own owner's effects.
- Pygame's frozen pose overrides any non-dead body; the client's pose helper
  applies frozen/terminal poses only while idle. This difference is recorded,
  not assumed equivalent.
- Fixture UUIDs and 3.2 s leases in Factory scenes are examples, not
  production lifetimes.

Consequences for this plan:

- **Conditions are a second extension point.** A new spell often brings a new
  lasting condition (Haste, Bless, Slow). Its look comes from
  `condition_recipes.json` + `condition_media.json` + per-asset sprite
  definition/storage JSON (N4, N5), not from the spell pipeline. Adding one
  today means editing those shared JSON files by hand.
- **One authored cue model for both sources.** The authored presentation
  input (§7.3) lists cues, and each cue names its source: a native Factory
  phase **or** a registered sprite asset. Replacing a sprite-sheet effect with
  Factory VFX later is then a data change to that cue, with no code change.
  The renderer already dispatches both kinds (`registered_media` and native
  components in `component_renderer.gd`); this plan only unifies how they are
  authored and imported.
- **Conditions get the same treatment as spells:** one authored file per
  condition presentation (application, sustain, removal cues; overhead marker;
  body material), discovered by folder, imported into the native index with
  import-time errors, iterated by generic tests. N4 and N5 become the import
  of these files rather than separate migrations.
- **Converting sprite sheets to Factory VFX is artistic work, not part of
  this plan.** Which of the 97 draft spells and 236 condition effects get
  Factory VFX, and when, is the user's decision; the pipeline only has to
  accept either source.
- **One runtime path; no legacy code kept alive** (user direction,
  17 October). The runtime JSON readers for spell drafts
  (`Authoring.spell` fallback), per-asset sprite definition/storage JSON
  (`registered_media.gd`), condition recipe/media JSON and
  `native_effects/index.json` are deleted. Their **content** is converted
  once, offline, into the same native Resources: a sprite-sheet effect becomes
  a native cue whose source is a texture with frames; a draft's cast animation
  becomes data in the spell's native resource. The look does not change, and
  that is a testable exact-parity gate. Native Factory VFX replace sprite cues
  later, one verified port at a time, as data edits.
- **Why conversion and not deletion of the content.** The Factory has recipes
  for all 132 spells, but its own catalog shows the lasting effects are not
  ported: `catalog/condition-port-queue.json` lists 160 conditions, all
  `complete_condition_lifecycle_verification_pending`, and
  `catalog/asset-port-coverage.json` reports 14 verified native ports of 1,204
  asset records (1,190 pending). Deleting the sprite content now would remove
  Haste's buff, overhead markers, class mantles, blindness, curses, surfaces
  and weather.
- **The Factory's 17 October delivery is the candidate source.** Its 89
  selected IDs and 15 condition markers enter as candidate cues in batches,
  under the rule below.
- **No new content before Gate A** (user direction, 17 October; also the
  three-operation plan's exclusion of bulk spell intake). Factory content is
  Stage 3 (§0): only after Gate A and Track S steps 1–6, starting with one
  pilot batch (Haste plus two or three condition effects) that proves the
  production/candidate cue model end to end, then batches of about ten, each
  gated by the startup/VRAM/frame benchmarks and the user's visual acceptance.

## 8. Measurement

1. **Boundary benchmarks.** Three fixed cuts from the final route's recorded
   journal: door reveal, one movement step, Fireball 1 onset. They replay
   through the live Session path (`play.gd --recording`, which feeds the
   journal through the ordinary Session/poll path), not Studio's recorded
   media plans, so live media-plan derivation and forecasts are exercised.
   A native windowed Forward+/Vulkan runner (not `--headless`, which has no
   renderer), N = 20, median/p95 per phase and per work unit (receivers,
   objects, actor layers, uploads, sorted entries). Serial runs only.
2. **Steady-frame benchmark.** Same path; 600 idle frames after the last
   action and 600 frames of one actor walking; per-phase medians and p95,
   using the committed frame-classification script.
3. **Unattributed intervals.** Correlate every interval with more than 5 ms
   outside the Player script against the recorded pipeline-compilation
   counters, from existing profiles.
4. **Profiling on and off.** Frame-pipeline phases report matched
   profiling-enabled and profiling-disabled measurements with startup timing
   (Operation 3 exit).
5. **Acceptance stays live.** The live route (81 checks, both Fireballs) is
   the acceptance measurement. Benchmarks attribute; they do not accept.

Benchmarks and baselines live under `tests/bench/`; per-run outputs go to
`.runtime/`. Only curated baselines are committed (decision D2).

## 9. Implementation phases

**Gates for every phase** unless stated otherwise:

- live route: 81 functional checks, both Fireballs;
- full native Studio run: 8,686 checks, zero failures/errors/warnings;
- focused actor checks 305 headless / 341 native with 12 exact pairs;
  environment 25,874 headless; native atlas suites;
- the eight focused suites from the checkpoint: media streaming 50, shared
  residency 44, priority 34, optional selection 12, selected-action sources
  37, environment streaming 35, shared admission 35, real-recorded world
  preview 10,079;
- the existing exact full-scene captures and received/final framebuffer pairs
  unchanged byte for byte;
- benchmarks (§8) not worse beyond their measured noise band;
- known open items do not get worse: no increase from 130 ObjectDB instances
  and 1 resource in use at live exit, or from the selection suite's 80-instance
  shutdown warning; the `portrait:creature.generic_caster` warning is tracked;
  `tests/media_role_race_checks.gd` is recorded as pre-existing red (stale
  fixture fields, handoff lines 381–386), not as a regression;
- read every Godot log for `SCRIPT ERROR`, `ERROR:` and warnings (Godot can
  exit 0 after a script error).

Moved members keep temporary forwarding properties on `play.gd` so the 66
tests that reach into it stay green. Each phase migrates the tests that touch
what it moved and deletes those forwards before it exits.

### Phase 0 — Benchmarks and baselines

Build §8.1–§8.4; commit the frame-classification script; record baselines at
`c2b0bfc`. **Exit:** the three boundary benchmarks and the steady benchmark
reproduce within a stated noise band on three consecutive runs.

### Phase 1 — Delete repeated work (frame) and isolate spikes

1. §5.5 items 1–4 and 6, in that order, each measured on its own.
2. **Targeting marks.** Add timers inside `ground_overlay` mark update (per-cell
   Node create/free, `_routes`, `_order`) and reproduce Fireball 1 frame 8189
   on the benchmark. Then make the dominant part incremental (for example:
   reuse mark Nodes across target sweeps, and re-order only entries whose key
   changed) with exact captures unchanged. Changing the painter comparator
   itself is **out of scope**: the same comparator is used in at least eight
   places (`play.gd` ~2789/2821/2868/3569, `world_preparation.gd` ~1852,
   `ground_overlay.gd` ~464/508, `quarter_view.gd` ~262,
   `environment_source.gd` ~133), and the binary-search merge needs them to
   agree. A native tuple sort would also order every int before every float
   (Godot's Variant comparison compares type first), and today's keys mix ints
   and floats. Record as a pre-existing risk: with mixed keys, `0` and `0.0`
   compare unequal yet neither is "less", so the comparator is not a strict
   ordering for those entries.
3. **Shadow light plane.** First add per-call timers inside the
   `update_light_plane` bundle (ground mesh resize, each ground material
   parameter, light position, `omni_range`) and reproduce movement frame 7962
   on the benchmark. Change only the call that measures dominant, and only so
   that exact shadow captures still match (for example: set it only when its
   value changed; or a unit ground mesh scaled by transform — the visibility
   shader uses `MODEL_MATRIX*VERTEX` and the composite only UV/SCREEN_UV, so
   this is very likely equivalent, but float rounding must be checked against
   the captures).
4. **Protocol schema parsed once** (N13).
5. **Spike attribution** (§8.3) and held-frame recording (§5.5 item 5).

**Exit:** the idle reuse check hits on unchanged idle frames; every remaining
duplicate preparation call site is documented as a same-frame re-check with
benchmark evidence, the rest are deleted; the two fallback allowances are
deleted; boundary benchmarks show no added frame at any group boundary; idle
Player CPU measured against §1 with the remaining gap reported per phase; each
spike change kept only if its benchmark improves and output is exact.

### Phase 2 — Cut `main.gd` out of the live chain

Move what play.gd uses (`position_camera`, `pixel_selected`, texture/row/
playback variables) into `sprite_sources.gd`; play.gd and the workshop both
extend it. **Exit:** play.gd no longer extends `main.gd`; none of `main.gd`'s
preloads load in the live game; captures unchanged.

### Phase 3 — Extract live interaction

Move choices, preview, commands, receipts, hover, approach, storage,
selection-media hints, native choice resources and input handling into
`live/`. `PlayerHUD` talks to the live code. **Exit:** play.gd has zero
references to `session`, `hud`, `context_menu`, `selection_media`; Studio panes
allocate no PopupMenu or `selection_media`.

### Phase 4 — Single publication path

Delete only paths with no production caller, after listing their callers
(initial world, rotation, Studio seek, `try_reset_hidden_playback` and the
sandbox included):

- the `_sync_world` synchronous else-branch, if only tests use it (fixtures
  move to the prepared path);
- the `_fallback` branches of `Delta.reconcile` and the full planner
  `_reconcile`, which live play already treats as hard failures — **not**
  `Delta.reconcile` itself, which applies `prepared_delta`.

Not deleted in this phase: `Characters.resolve` (a live path for non-boundary
actor revisions; it can go only after those revisions use prepared rows, which
is a separate measured change) and `_reconcile_actor_layers` (sandbox path;
revisit after Phase 6 gives the sandbox explicit playback configuration).

Keep entry insertion order exactly: the atlas reservation order depends on it
(comment near `play.gd` ~1118). Extract the media block (play.gd 1755–2528)
into its own script only if its variables prove self-contained, passing its
inputs explicitly rather than the host; no other split is planned.
**Exit:** the listed paths are deleted with their former callers recorded,
net lines removed are reported, and the retained paths are documented with
their production callers.

### Phase 5 — Remove back-references

`WorldPreparation` takes an input snapshot (generalizing `capture_static`) and
returns a publication record; it writes nothing into the host. The snapshot
captures **references**, not deep copies, so it stays cheap; `actor_bases`
holds live `visual_actors` and playbacks (`world_preparation.gd` ~198), so the
existing publish-time checks (stale epoch, quarter, `can_publish_membership`)
stay. Component,
blood and spell renderers return entry changes instead of appending to
`actor_entries`; the spell renderer receives its cull layer instead of editing
the camera. `ActorConstruction` receives explicit operands instead of a host.
**Exit:** no `host.`/`world.` writes remain in those files; reads are limited
to the input snapshot.

### Phase 6 — Separate the applications

Playback configuration record (§5.4); delete `external_playback` and
`external_clock`; rename play.gd to `presentation/world_view.gd`; add
`live/live_game.tscn` as the main scene; separate settings sections; sandbox
uses explicit state injection and loses its test flags; add the separation
test (§5.1). **Exit:** zero `external_playback`/`external_clock`; the sandbox
loads nothing from `res://tests`; the separation test passes; Studio does not
write the live settings section.

### Phase 7 — Bounded process caches

Delete the cross-instance `_release_actor_source` callback from
`_prune_character_media` (each view releases its own bindings from residency
changes it observes). Bound `_prepared_packets` and `NativeStartup._state` to
the warmup scope (§7.3). **Exit:** the callback is gone; a test shows both
caches shrink after a scope change.

### Track N — Native data (step 1 in Stage 1; steps 2–4 in Stage 2)

Order by ease; measure each candidate on §8 before work. Each conversion
follows §6.1 and ships with an importer test proving value parity.

1. Deletions first: N1's per-call deep copy, N10, N11, N12, N13 (with
   Phase 1), N7 and N8 moved to workers.
2. Shape changes on the first plan: N2, then N6 only if measured on the
   critical path.
3. Compile path: N3, then N1's split. N4 and N5 are delivered by Track S
   step 6 (condition and sprite-effect import), not separately.
4. N9 lands with Track S.

### Track S — Spell/VFX pipeline (steps 1–6 in Stage 2, existing content only; step 7 in Stage 3)

1. Typed runtime spell Resource and the single importer with import-time
   errors (§7.3). **Gate:** exact parity with the current
   `.derived/native-spells` output for all 30 active spells, including
   selection, timing, palette and deferrals.
2. Adapter capability declared by adapters; per-spell importer branches moved
   into the authored inputs' clip overrides.
3. Generic tests and Studio capture iterate the index; delete count and name
   constants (including the `== 30` and deferred-list assertions, which become
   checks over the authored production and candidate cues).
4. Missing `current` fails loudly. **Cutover (D6):** import all 127 spells
   (draft-only and deferred spells with their current look as native cues),
   then delete the runtime spell-draft fallback. **Gate:** exact captures for
   a cast of every draft-only spell family and all four deferred spells.
5. Bounded caches and warmup scope (with Phase 7).
6. **Conditions and sprite-sheet effects (§7.4).** One authored cue model
   whose cues name a native phase or a registered sprite asset; one authored
   file per condition presentation; the importer covers both and absorbs N4/N5.
   Body cues and markers (§7.4) are imported from the same authored files.
   Then delete the runtime sprite definition/storage and condition JSON
   readers. **Gate:** exact parity for all 236 current condition media entries,
   the 36 draft spells with sprite effects, and every implemented body cue
   (colour, opacity, poses, outline, flowing-film ramp).
7. **Missing body cues (parity audit F02, F05, F10, F11, F13–F17), after the
   basics.** Stone/bark/Stoneskin, captured petrification pose, eased opacity
   transitions, item materials, appearance layers, Blur distortion,
   Enlarge/Reduce scale, Mirror Image copies, Banishment echo. Port the
   Factory's native body-treatment components (§7.4) into the renderer as body
   cues, adapting seams rather than replacing client code. **Stage 3: only
   after Gate A** and Track S steps 1–6, one at a time, each with its audit
   reproduction and before/after captures; the new look needs the user's
   acceptance.
8. **Exit (steps 1–6):** on a discarded scratch branch, add a synthetic fixture spell (not
   a real or deferred spell) using only §7.3's steps 2–4, with no code or test
   edits; record what was needed. Repeat with a synthetic condition whose
   sustain cue uses a sprite asset, then switch that cue to a native phase
   with a data-only change. This proves the pipeline, not any spell's or
   effect's artistic acceptance.

### Track R — Reveal boundaries

The handoff's three boundaries (lines 583–598) continue under the
three-operation plan:

1. Scene-thread constructor/atlas packet work as one owner change, from the
   90.7 ms disjoint account: atlas 24.1 (the largest owner), ordinary fixture
   constructors 12.3 and the untimed 19.8 ms "other". Keep clocks and Nodes on
   their correct owner and preserve canonical seal/publication.
2. Changed-state native publication/sampling, sharing the shadow-plane and
   targeting-mark reproductions with Phase 1 (the handoff's "draw-sort
   27.327 ms" is the `ground_overlay` mark update, §3.4).
3. Received-action opening/owner handoff, from the frontend totals in §3.3.

**Sequencing rule.** Track R and Phases 1, 4 and 5 touch the same files and
run one at a time, each with a single owner:

| Work | Files |
|---|---|
| Phase 1 | `play.gd` (`_process`, `_media_ready`, `_world_ready`, `_prepare_optional_work`, `_warm_media`, `_sort_draws`), `presentation/timeline.gd`, `lighting_2d.gd`, `canvas_shadows.gd`, `native_light_atlas.gd` (sync early-out), `media_warmup.gd`, `component_renderer.gd`, `blood_renderer.gd`, `sdk/protocol.gd`, `session.gd`, `journal.gd`, `transport.gd` |
| Phase 4 | `play.gd` (`_sync_world`, actor sync), `native_light_delta.gd`, `native_light_atlas.gd`, `world_preparation.gd` (fixture path) |
| Phase 5 | `world_preparation.gd`, `component_renderer.gd`, `blood_renderer.gd`, `native_spell_renderer.gd`, `actor_construction.gd` |
| Track R | `world_preparation.gd`, `native_light_delta.gd`, `native_light_atlas.gd`, `canvas_shadows.gd`, publication in `play.gd`, `timeline.gd` (opening handoff) |

Track R runs between those phases, never concurrently with them, and never
with two agents editing the same file. During this review another process
edited play.gd and world_preparation.gd while they were being read; that must
not recur during structural phases.

## 10. Culprit register

| Culprit | Owner | Benchmark | Phase/track |
|---|---|---|---|
| Idle readiness re-preparation (~0.7–0.9 ms; reuse check never hits) | `_media_ready` / `component_renderer` | Steady | 1 |
| Optional lane at idle (~2 ms) | Optional lane owners | Steady | 1 |
| Per-frame shadow, atlas sync and light projection (~2.4 ms) | Shadows, atlas, lighting | Steady | 1 |
| Per-frame media demand (~1.3 ms) | Media block | Steady | 1 |
| Targeting-mark update 27.0 ms | `ground_overlay` | Fireball onset | 1 |
| Shadow light plane 10.75 ms | `canvas_shadows.gd` | Movement | 1, R |
| Unattributed outside-script intervals (8–22 ms) | — | All | 0, 1 |
| Door main preparation 90.7 ms | WorldPreparation | Door | R |
| Construction starting 316 ms after click | WorldPreparation | Door | R |
| Opening frontend 18–68 ms plus 39–63 ms tail | Session / compiler / opening handoff | All actions | R |
| First required metadata plan 138 ms | Media plan worker + native data | Door | N |
| Protocol schema parsed 3× | SDK | Startup | 1 |
| Spell cache growth and warmup scope | Process caches | Startup | S, 7 |

## 11. Risks

- **Concurrent edits.** Structural phases need one owner per file set (§9
  sequencing table).
- **Atlas reservation order** depends on entry insertion order; exact captures
  are the guard.
- **Removing work from readiness or deleting call sites** can add a frame at
  every group boundary; admission stays in the plan-application call and each
  same-frame re-check stays unless the boundary benchmark proves it unneeded.
- **Skip keys that miss inputs** would show stale output; display time is
  never a key, and residency/native progress must be revisions before any
  readiness recomputation is skipped.
- **Mixed int/float painter keys** are a pre-existing ordering risk (§9
  Phase 1.2); not changed by this plan.
- **Seeking Factory sources.** Studio seeks to arbitrary times, but the
  Factory states that seeking stateful rigid-body/GPU sources still needs its
  own contract, and its evidence uses per-phase `simulation_hz` up to 144 Hz.
  Sources that cannot seek deterministically must be identified at import and
  given an explicit Studio behaviour before they become production cues.
- **Carried Factory code.** Importing the `factory/` script closure brings
  Factory code into the client; it stays under one namespace, is updated only
  by re-import, and is never edited in place.
- **Float parity** in every native conversion; `.res` only; parity tests in
  the importer.
- **Test forwards** can outlive their phase; each phase deletes its own.
- **Studio's shared account** is intentional and stays.
- **Fresh clones** lack `.derived/`; the plan makes that a loud startup error
  and documents the import command.

## 12. Decisions for the user

- **D1 — withdrawn.** Earlier revisions offered a larger allowance while the
  display clock is held, based on held frames measuring 7.2 ms. The
  correctness review showed that 35 of those 38 frames were the small
  pre-reveal room; full-scene held frames took 14.2–55.4 ms. There is no
  evidence of headroom, and the handoff rejected raising the allowance
  (line 277). Not proposed.
Open decisions below carry a default that applies unless the user decides
otherwise.

- **D2 — Per-run evidence in Git.** `c2b0bfc` again commits about 20
  regenerated check JSON files. Default: commit curated baselines only; send
  per-run evidence to `.runtime/`.
- **D3 — New named pieces.** The plan adds a playback configuration record,
  a `live/` folder with the extracted live code, and a renamed renderer
  script. It adds no facade, scheduler, hub class, registry or class
  hierarchy. Default: accepted.
- **D4 — Project layout.** Default: one Godot project with separate entry
  scenes (not separate Godot projects).
- **D5 — Spell warmup scope.** Default: controlled actors' offered spells plus
  received lookahead (not whole roster or whole catalog).
- **D7 — Gate A thresholds (§0).** Default: the user's existing minimums —
  door and movement holds below 100 ms, steady frame median at or below
  10 ms, no unattributed interval above 16.7 ms — on the median of three live
  routes. Only the user moves the gate.
- **D6 — resolved by the user (17 October): no legacy runtime paths.** The
  draft fallback, sprite JSON readers and condition JSON readers are deleted.
  To keep today's look, their content is converted offline into native cues
  first (§7.4); the four deferred spells (Aid, Bless, False Life, Sacred Flame)
  keep their current look — cast animation, condition placement, and Sacred
  Flame's 2D flame and hit flash — until the user accepts their Factory VFX.

## 13. Review record

| Reviewer | Verdict | Disposition |
|---|---|---|
| Anti-slop | Approve with required changes (B1–B6) | Applied in revision 2: §5.5 rewritten without lanes or cached readiness; Phase 4 merged into Phase 1; baseline from one frame set and targets relabelled; deletion exit criteria on every phase; Track N limited to shape changes, N6–N8/N13 reworded; Track S authored/derived split, folder discovery, capture profile kept offline, existing missing status reused, one cue type; D1 estimate removed. Cuts accepted: directory relocation, facade, three playback classes, five-way renderer split, hub class, typed records, runtime lane accounting. Kept, with reason: one separation test (§5.1), as the only automated guard for the user's separation requirement. |
| Plan adherence / evidence | Approve with required changes (1–7) | 1 (idle baseline), 4b (40%) and 5a (spell status) were already resolved by revision 2. Applied in revision 3: shadow cause relabelled as an unverified hypothesis, the second mesh dropped, Phase 1.3 isolates each call first (2); sequencing fence widened to Phases 1, 4, 5 with file sets (3); exact rejection quote, one-account framing (§4.4) and Operation 3 link (4a, 4c); spell activation step, synthetic fixture for the Track S exit, D6 options disclosing the deferred-spell change (5b–d); Factory `.tres` not used — Factory JSON stays the import input, importer records the Factory revision, exact parity gate (6); gates extended with the eight focused suites, leak/warning baselines, pre-existing red test and profiling on/off (7). Non-blocking items applied: onset/publication targets and pre-onset spikes in §1, Track R first targets and frontend totals, Operation 3 framing, measured-cell sources, outside-Player column, primed-source count dropped, 10 revisions, windowed runner, line 105/106, N9 citation. |
| Correctness / anti-OOP | Approve with required changes (1–6) | Applied in revision 4: the Fireball 27.3 ms spike re-attributed to the `ground_overlay` targeting-mark update (no static sort ran), comparator change ruled out of scope with its eight call sites and int/float Variant ordering recorded (1); held-frame headroom claim removed and D1 withdrawn, idle class composition and full-scene row added (2); `Characters.resolve` and `Delta.reconcile` recognized as production paths, sandbox dependence on `_reconcile_actor_layers` recorded, Phase 4 narrowed to paths with no production caller (3); admission stays in the plan-application call, same-frame re-checks kept unless the benchmark proves them unneeded (4); skip keys exclude display time, residency/native progress need revisions, and the existing never-hitting reuse check is fixed first (5); per-pane lanes already removed in revision 2, and §5.5 now states that panes share the one account (6). Non-blocking applied: shadow equivalence notes, Protocol shares only parsed dictionaries plus the fourth parse site, call-site counts and facing lines, `session_timeline` nesting, Phase 5 reference snapshot. Anti-OOP: already satisfied by revision 2 (passive playback record, no hub or facade, typed records deferred; `Entry` would be the only candidate). |

All three reviews have reported, and every blocking finding has been applied
to this text. Plan-adherence item 6 ("Factory JSON stays the import input") is
superseded by the Factory's 17 October handoff, which designates its `.tres`
Resources and their script closure as the production format (§7.1).

**Review coverage by stage.** Stage 1 (§0: Phases 0–1, Track R, Track N
step 1) and the structural phases were in the reviewed revisions; the
reviewers' required changes are applied but they have not re-read the final
text. Added after the reviews at the user's direction and **not yet
reviewed**: §0 (execution order and Gate A), §7.4 (drafts, sprite sheets,
conditions, body and animation treatments, one runtime path, no new content
before Gate A), Track S steps 4, 6 and 7, the production/candidate cue model
(§2, §7.3), the deferred spells' fallback description (§7.1), D6 and D7, and
the Factory handoff integration (§7.1, §7.3, §7.4, §11). Stage 1 can start
now; the unreviewed sections govern Stage 2 and 3 work and should be
re-reviewed before that work begins.
