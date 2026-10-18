# Client structure plan — progress ledger, 17 October 2026

Ledger for [the client structure plan](CLIENT_STRUCTURE_AND_NATIVE_DATA_PLAN_2026-10-16.md)
on branch `feature/opus-refactor`. Server timings are excluded by the user's
direction (separate backend work). All live numbers come from the real Gallery
spell route (`tools/live_routes.sh`, i.e. `tools/play.py --scenario
gallery_sorcerer --test-script res://tests/live_spell_checks.gd
--live-fireball-ui --profile-pipeline --profile-view-size 18`), native Windows
Godot 4.7.2 Forward+/Vulkan, RTX 5090, VSync off. Summaries come from
`tools/route_summary.py`. Every listed run passed 81 functional checks with no
script errors.

Note on local settings: the live player reads the user's
`user://rendering_settings.cfg`, which currently has `fire_light_flicker=true`
and `light_strength=0.43`. Flicker makes wall-torch light positions move every
frame; this is intended behaviour and is kept.

## Baseline (`c2b0bfc`, median of 3 live routes)

Runs `20261016T230002`, `20261016T230215`, `20261016T230254`.

| | Door | Move | Haste | Fireball 1 | Fireball 2 |
|---|---:|---:|---:|---:|---:|
| Packet → first animation | 89.2 | 86.3 | 52.0 | 81.5 | 98.2 |
| Media / world hold | 9.2 / 265.5 | 0 / 0 (one run 1,319) | 0 / 20.8 | 35.1 / 29.5 | 0 / 46.2 |
| Largest post-onset frame | 42.7 | 49.3 | 35.8 | 31.5 | 36.3 |

Idle same-view frame median 15.67 ms (script 12.23 ms); frames above
16.7 ms per run: 838, 428, 330. The first run of a session was markedly worse
(cold driver/pipeline caches); later comparisons use warm runs.

## Phase 0 — measurement tools (commit `dec2527`)

- `tools/live_routes.sh N` — N serial live routes; prints run directory and
  check/failure/script-error counts.
- `tools/route_summary.py RUN...` — per action: packet→animation, media/world
  hold, post-onset max; frame classes (idle, animating, held); idle phase
  medians; every frame above 16.7 ms with disjoint Player parents, children,
  time outside the Player script, GPU/render CPU and pipeline-compile deltas;
  medians across runs.
- `tools/run_checks.sh [--native] tests/x.gd[::--arg=value]` — check scripts
  through Windows Godot with a per-test timeout (`CHECK_TIMEOUT`, default
  300 s); reports exit code, script errors and the check summary.

Deviation from plan §8.1: the boundary benchmarks use the real live route
(about 35 s per run) repeated three times instead of a recording replay,
because recording replay makes every operation available at once and so
under-reports holds. Holds are judged on three-run medians.

## Phase 1 — repeated per-frame work deleted (commit `dec2527`)

| Change | Evidence | Effect (idle medians) |
|---|---|---|
| Component preparation reuse accepts the fresh empty idle group (`component_renderer.gd` `_same_resource_groups`) | `component_prepare_reuse` never appeared in idle frames; `required_components` charged 732 µs | `timeline_media_ready` 0.91 → 0.20 ms; `component_prepare` 0.73 → 0.009 ms |
| Media due set composed only when a part map changes; current-set readiness checked only when a future cut or forecast could join (`play.gd` `_prioritized_media`) | `media_prioritize` 1.39 ms, of which `MediaWarmup.ready` 1.29 ms (onset hint paths force its per-path loop), twice per frame | `media_prioritize` 1.39 → 0.03 ms |
| Optional maintenance returns when settled (`media_warmup.gd` `prepare_optional`) | 0.74 ms per idle frame | applies when the optional library has finished accounting |
| Generated shadows retain unchanged actors (`canvas_shadows.gd` `sync`): key = layer versions/transforms/bind fields, contact, view, light **ranking** revision, dominant source's live fields; hide only dropped helpers | key never matched: flicker moves torch light positions each frame, but ranking deliberately uses each flame cycle's mean | `modular_shadows` 1.39 → 0.48 ms; 6/6 actors retained in 186/200 idle frames |
| Optional selection and family accounting read each family map once (`_select_optional`, `_step_families`) | see spike S1 below | targeting burst removed |
| Native spell support adoption runs only when a texture enters or leaves residency or an actor layer's displayed path changes (`native_scene_support.gd` `adopt`; new `texture_revision` in Play, bumped on upload-create and prune) | during Fireball, the spell prefetch re-walked every actor layer each frame, with two body-descriptor lookups per layer, to rebuild an unchanged mask map | prefetch minus image requirements 0.65–0.71 → 0.48–0.60 ms per Fireball frame, lower in all three interleaved pairs (`T021535`… vs `T021628`…). Native scene support 12,939 checks; native spell playback has the same 6 failures as `af3daa2`. |
| Native scene proxy uniforms written only when a value changed (`native_scene_support.gd` `sync`; the support owner creates and alone writes these proxy materials; the last written values live in the material's metadata, cleared when proxies are reset) | during a spell, every visible actor layer's depth proxy received nine `set_shader_parameter` calls per frame, each marking the material for a uniform update | in run `T023554`, proxies were rewritten 138 times in 37,339 proxy-frames (671 of 682 command frames wrote none), about 490 redundant writes per frame avoided. Support sync cost was lower in 2 of 3 interleaved pairs (−0.10 to −0.17 ms) but drifted within the third. The output-material uniforms stay re-asserted every frame: `native_scene_support_checks` requires that an outside overwrite (`output_recopy`, `stamped_recopy`) is restored. |
| Blood deposits: tile screen visibility recomputed only when the camera, viewport or tile after-value changes; deposit position and four uniforms written only when a value changed (`blood_renderer.gd` `sample`; the renderer alone writes its deposit nodes/materials) | every visible residue tile ran five camera projections and five uniform/position writes each frame while blood was present | `blood_fields` median 0.172–0.186 → 0.111–0.124 ms over ~1,000 blood frames per run, lower in all three interleaved pairs (`T025250`… vs `T025340`…); p95 0.65–0.68 → 0.60–0.61 ms (kernel rebuild and upload during landing remain). Blood checks identical to `d737883` (phase preparation 1,100, residue 281, tile index 51, resource poll 20, native partition; loading 101–103 by frame timing; authority, kernel cache and the two studio blood suites exit 2 on both). |
| Targeting marks and floor geometry no longer read native buffers back from the GPU (`ground_overlay.gd` `_batch_changes` keeps its transform buffer and submits it whole; `sprite_sources.gd` `_ground_publish_changes` submits its existing `ground_buffer` mirror, the same float encoding, instead of per-instance writes) | the plan's Fireball targeting spike. With a probe: a flat mark update with **one** changed cell took 23 ms (frame 37 ms). Godot's RD renderer serves a per-instance write on a multimesh whose buffer was uploaded whole, and which keeps no CPU copy, by first reading the whole buffer back from the GPU (a full stall) | mark updates above 2.5 ms per run: 0 (current) vs 3–6 on `d990882`, worst 2.5 vs 6–9 ms (and 15–20 ms in two of three earlier runs); mark-update time per run 15–16 vs 32–40 ms (`T031412`… vs `T031507`…). Overlay delta checks 13 (headless) / 17 (native, exact visible transforms), overlay support 67, sparse world preparation 78, world atlas preparation 172 (native), native atlas lifecycle 221. |
| Ground overlay mark and route shaders compiled at startup with the other reveal shaders; equal mark styles reuse the previous material when cells change | a single new overlay cell or route cost 5.5–6 ms (first shader use, R4); the 697-cell area set/clear resolved a material key twice per cell | the 5.5–6 ms events are gone; full-area updates 2.6–3.1 → 2.1–2.5 ms |
| Shadow light plane is a unit `PlaneMesh` sized by its node transform (`canvas_shadows.gd` `_create`/`_update`) | plan Phase 1 item 3. Sub-timers showed the cost was `PlaneMesh.size` (surface rebuild), 2.4–9.9 ms when a move starts (frame up to 43 ms). The visibility shader reads `MODEL_MATRIX*VERTEX`; unit vertices ±0.5 times the size are exact (power-of-two scale), the same as the sized plane's ±size/2, and the normal stays (0,1,0) | `update_light_plane` max 0.10–0.13 ms in three runs vs 10.2–13.1 ms (2–4 events above 1 ms per run) on `901340c`, interleaved (`T040606`… vs `T040700`…). Parity: the Studio replay's seven primary scene captures are byte-identical to `901340c`'s; the Studio window captures differ only in a 120×18-pixel UI text area (x 1435–1554, y 49–66, timing labels). Shadow scalar capture identical; shadow scalar 19, idle and preparation suites give the same results as before. |
| Protocol schema and identity parsed once per path pair per process (`sdk/protocol.gd`, a mutex-guarded static map; Protocol objects share only the parsed dictionaries, which nothing mutates, and keep their own pattern/envelope/producer caches) | plan N13 / Phase 1 item 4. Measured: each `Protocol.new()` costs 86–98 ms (GDScript strict parse of the 512 KB schema plus the vocabulary walk); the live game builds one for the session and one for its journal on the scene thread at startup, and one on the transport thread | first `Protocol.new()` 86 ms, later ones 0.003–0.011 ms: about 190 ms of scene-thread startup and 95 ms of transport-thread work removed. SDK protocol 61, journal 30, choices 86, decimal 3,404, transport 358 and reducer suites identical to `990b491`; live route 81/0. |
| Movement reference speed read from the native presentation catalog (`catalog.tres` / `PresentationResourceCatalog.movement_reference_speed_feet = 30.0`) instead of the 213 KB animation schema (`authoring.gd`) | plan N10: the first movement compile parsed the whole schema for its one supplied default | the compiler no longer reads the schema; new `tests/movement_reference_speed_checks.gd` proves the catalog value equals the schema default exactly (30.0, float) and that a movement compile leaves the schema unparsed. Native authoring 286 identical; presentation checks have the same 2 failures as `77ad0e6`; live route 81/0. |

Result after Phase 1 (median of 3 runs `20261017T001059`, `T001138`,
`T001215`): idle same-view frame **8.77 ms** (p95 14.05; script 6.60 ms);
door world hold 218.1 ms; spikes above 16.7 ms per run 235, 136, 139.

## Spike attributions

### S1 — Fireball 1 targeting burst (resolved)

Every baseline run showed 3–9 consecutive frames of 31–61 ms while the
Fireball target sweeps. In the burst every Player phase was 3–5× its normal
cost at once (atlas, shadows, sprite sampling) plus 10–19 ms outside the
script, and decoding stalled (no decode completions for ~10 frames).
Main-thread work in the burst: `media_optional_pending` 2.9–5.0 ms (decode
queue re-partition), `media_optional_selection` 1–6 ms, `selection_media`
up to 8.6 ms (`Catalog.source_snapshot` 2.3–2.5 ms, `_selection_media_budget`
~2.5 ms). Cause: each hover replaces the hint family, bumping
`selection_revision`, which launches a new `_select_optional` worker pass over
the whole optional library. That worker (and `_step_families`) performed
eight per-path lookups on shared family dictionaries with a fresh `{}`
default argument each — an allocation and reference-count storm contending
with the scene thread and decoders. Diagnostic: disabling the re-selection
removed the burst (run `20261017T000518`… see `T234738`: 2 frames above 25 ms,
max 36.6). Fix: read each family map once per family (identical results).
After the fix (run `20261017T000518`): Fireball 1 targeting 3 frames above
25 ms, max 28.5 ms, p95 20.0 ms.

### Spike causes (tool)

`tools/route_summary.py` now labels every frame above 16.7 ms with one cause,
checked in order:
- `pipeline_compile`: a render pipeline compiled in that frame;
- `world_publication`: `world_sync` of 3 ms or more;
- `preparation_chunk`: a single preparation step of 3 ms or more;
- `outside_script`: more time outside the Player script than inside it;
- a phase burst: optional ≥ 4, actor sample ≥ 5, native lighting ≥ 5,
  timeline ≥ 5 or draw order ≥ 4 ms;
- `steady_load`: cost spread over ordinary per-frame phases, labelled by
  command or frame class.

It prints counts per run and across runs.

Three slow-window runs on `d990882` (`T025250`, `T025423`, `T025554`, 584
spikes):

| Cause | Count | Max | Cause in detail |
|---|---:|---:|---|
| steady load, Fireball | 306 | 24.9 | Fireball frames run at 12–15 ms median in this window. Script: spell/actor sampling ~2.4, native lighting ~2.2 (the moving spell light re-ranks every actor shadow, 1.2), optional preparation ~1.5, draw order ~1.4, timeline ~0.9. Plus 3–4.5 ms outside the script: GPU particles, the 8,192-wide atlas viewport, native effect viewports, per-actor shadow viewports. Repeated work found here was removed (rows above). Still open: ~0.24 ms per animating frame spent returning from the timeline's media readiness callable (below). |
| actor sample burst | 57 | 33.3 | Hit and death frames: blood landing (kernel rebuild and upload, 1–3 ms), new clip binding for the hit actor, spell sampling. |
| steady load, idle | 51 | 27.6 | Settling after Fireball: blood fields, the spell's lingering components, optional media maintenance draining hundreds of changed paths. |
| optional preparation burst | 32 | 26.9 | Optional media maintenance (budgeted, finite: it drains the changed-path queue); CPU image release (`media_release_cpu` up to 5.6 ms when large decoded images are freed). |
| timeline burst | 27 | 29.9 | Command boundaries: timeline advance/apply, media plan demand and preparation steps on the first frames of a group. |
| outside script | 26 | 56.0 | First interactive frames after initialization (driver/swap-chain warm-up, ~54 ms once per run), and frames where rendering outweighs script work. |
| native lighting burst | 24 | 30.8 | Shadow re-ranking when a spell light appears or moves; one projection burst of 11 ms after the door (camera follow re-projects all receivers). |
| pipeline compile | 23 | 40.7 | First draw of a material/pipeline variant (spell particles, haste effect, newly revealed content). One-time per session. |
| world publication | 10 | 35.6 | The door and move cut publication frames (atlas adoption of ~1,100 receivers, world sync, shadows, draw sort). |
| draw order burst | 10 | 26.1 | Targeting-mark updates and full re-sorts after membership changes. The 15–23 ms targeting outliers were the GPU readback fixed above. |
| preparation chunk | 4 | 25.2 | First construction frame of a reveal (result adoption, atlas begin, environment capture). |
| steady load, move / open | 14 | 23.1 | Animating frames of those commands under the same per-frame load. |

Open, not repeated-work: the media readiness return cost. Timestamps on both
sides of `media_ready.call(first)` show 0.15–0.25 ms between the callee's
last statement and the caller's next one, in animating frames only. A no-op
method called the same way with the same argument costs 0.002 ms. Locals were
released explicitly without effect, and static memory grows ~7 KiB across the
return. The cause lies below GDScript and was not found.

### S2 — remaining spikes after Phase 1 (superseded by the table above)

510 frames above 16.7 ms over three runs: 353 between 16.7 and 20 ms,
105 between 20 and 25, 43 above 25. 394 fall inside the two Fireball
commands; most are animating frames dominated by `actor_sample`. Fireball 2
animating frames: median 14.5 ms, p95 19.2 ms; parents actor_sample 2.66
(native spell sample 0.87, native support sync 0.85, blood 0.44), native
lighting 2.47 (shadows 1.38 — the moving spell light legitimately re-ranks
every shadow), optional preparation 1.68 (native prefetch 0.79, media
maintenance 0.61), draw order/output 1.47, timeline 1.0. 30 spikes are
dominated by time outside the Player script; 26 coincide with pipeline
compilations. Detailed per-spike attribution continues in the next update.

## Door hold decomposition (after Phase 1, run `20261017T001138`)

World hold 218 ms (cue 433 → publication 651 ms after click). Worker
derivation of the revealed room runs sequentially (rows 17.7, routing 14.3,
sources 13.8, ground 9.6, support 6.5, walls 6.5, visibility 3.0, actors 2.9,
blood 2.5 ≈ 77 ms) and construction cannot start before it ends (~276 ms).
Construction 276 → 502 ms, membership/order 502 → 540, atlas overlap
540 → 608, publication ~650. During the 30 held frames (median 5.85 ms) world
work was charged 48.4 ms. The hold is set by the scene-thread work left at the
cue, delivered at 2 ms per ~6 ms held frame.

### R1 — fixture bodies on the worker path (done)

The 11 animated-flame fixture rows were the only static rows built by the
scene-thread ordinary constructor (12.5 ms, ~1.1 ms per row versus ~0.04 ms
to adopt a worker row). `EnvironmentSource.row_packet` now prepares a lit
row's static body like any prop; derivation keeps the row's full source
closure (body plus flame frames with optical facts); the worker branch waits
for those sources, adopts the body, then builds and primes only the flame on
the scene thread. `object_ordinary_constructor` no longer appears; objects
19.8 → ~16 ms, dispatch 26.6 → ~21 ms. Three-run median door world hold
218.1 → **198.6 ms** (runs `20261017T003002`, `T003041`, `T003119`).
Checks: environment source preparation 25,877 (test updated to the new
contract: a lit row's body equals the same prop's packet, and no flame entry
is prepared), world atlas preparation 54, live environment admission 36,
world preview 10,079.

### Current door critical path (run `20261017T003041`, hold 443 → 642 ms)

| Window | Duration | Work |
|---|---:|---|
| 443–498 | 55 ms | construction tail on the scene thread (2 ms slices) |
| 498–515 | 17 ms | support capture |
| 515–581 | 66 ms | atlas planner worker: group materials 35.8, receiver records 16.2, outputs 5.4, canvas items 5.0, projection 3.6 — proportional to the 279 new sources (~0.2 ms each); existing groups are reused |
| 581–596 | 15 ms | bind 1,156 receivers (bulk) and 278 outputs |
| 596–631 | 35 ms | one publication frame: atlas sync 10.1, world sync 4.0, shadows 3.6, timeline 4.8 |

### Measurement drift and the A/B method

Later in the session the same committed code ran markedly slower: idle
same-view frame 8.0 → 9.8–13.0 ms and the door hold 198.6 → 250–270 ms, with
every Player phase about 25–50 % slower at once. Memory, CPU load and clock
were normal, and pinning Godot to either CCD of the 9950X3D (`AFFINITY=0xFFFF`
or `0xFFFF0000`, new option in `tools/live_routes.sh`) gave the same times, so
the drift is in the machine state, not the code. From here on, a change is
judged by **interleaved** runs (current, committed, current, …, three of each)
inside one window, never against numbers from an earlier window.

### R2 — static receiving materials built by the resource worker (done)

The planner worker created one receiving `ShaderMaterial` per new static
source (225 per door, about 44 uniforms each) and one output material per
source, only after construction ended. Both are fully determined by the
private environment producer's own operands: the source material, the seeded
candidate visibility and, for a non-floor non-water row, no support mask.
`EnvironmentResources.build_private` (through
`private_environment_binding`) now builds them, using the same constructors
the planner uses (`Delta.static_group`, `Delta.realize_output`). The planner
adopts a prepared group when its key matches, otherwise it builds one as
before. Planner group stage 35.8 → 26–28 ms (220 of 225 groups adopted),
output stage 5.4 → 3.4 ms. The rest of that stage is receiver records
(16–17 ms) and canvas items (5 ms), which is bookkeeping, not materials.

### R3 — support and wall geometry overlap the rest of derivation (done)

`GroundOverlay.prepare_support` (8–10 ms) and `WallReveal.prepare_geometry`
(7–9 ms) are pure functions of the tile after-values and visual rows and
touch no catalog cache. `derive_static` now runs them in one side task
started right after the row patch, joining before the result is assembled
(`side_wait` ≈ 0). Visibility rises from ~3.7 to ~7 ms while they run
alongside it, from shared-read contention. The net cut on the derivation path
is about 10–12 ms.

### Result (interleaved, same window)

| Runs | Door world hold, per run | Median |
|---|---|---:|
| Current (`T010632`, `T010810`, `T010945`) | 235.0, 197.2, 179.5 | **197.2** |
| Committed `3e4d22e` (`T010729`, `T010904`, `T011039`) | 255.6, 250.0, 191.1 | 250.0 |

The current code is faster in every pair, by 53 ms (21 %) at the median.
Idle frames are unchanged within noise (9.6 against 9.8 ms). All six runs
passed 81 checks with no script errors. Checks: world atlas preparation 54
(headless) and 172 (native framebuffer comparison), live environment
admission 36, environment source preparation 25,877, world preview 10,079,
world preparation sparse 78, static forecast 23, reveal scenery publication
10, environment streaming 35, prepared admission 28, preparation admission
35, light preparation ownership 17.

### Current door critical path (after R2/R3, run `20261017T004726`)

From packet to publication is about 430 ms:

| Window | Duration | Work |
|---|---:|---|
| derivation | ~79 ms | worker: rows 18–20, routing 14–16, sources 16, ground 9–11, visibility 7, actors/blood 6; support and walls now hidden |
| construction start | ~70 ms | actor and environment resource capture; the environment worker waits on textures from media upload; atlas begin 3.8 ms |
| objects and actors | ~150 ms | 107 objects and 6 actors at ≤ 2 ms per frame (media upload takes 0.4–0.8 ms of each frame's allowance before the cue) |
| atlas capture and membership | ~38 ms | seal 2.4, supports/receivers 3.6, membership, scenery, order |
| planner wait | ~43 ms | planner worker 54–62 ms: receiver records 16–17, plan specs 6.5–12.5, spec copy 7.2, canvas 5, floor addresses 4.2, projection 4.2, outputs 3.4, plan reservations 2.5 |
| reserve and bind | ~15 ms | 3 frames |
| publication frame | ~34 ms | atlas sync, world sync, shadows, timeline |

The door's scene-thread work totals 72.7 ms over 43 frames, 27 of them
held: objects 16.5 (of which 6.5 ms is the one-time `Texture2DArray` build of
a newly seen flame clip), actors 12.2, atlas source capture 11.1,
bind/capture/reserve 9.5, environment capture 2.8.

### R4 — first shader use moved to startup (done)

The 6.5 ms object chunk was not the flame's texture array (its upload is
0.29 ms). A probe on native Godot showed the cost is the **first** assignment
of a shader to any material, paid once per shader per session and not again
after that material is freed (`fixture_flame` 5.5 ms, `canvas_fixture_flame`
2.5 ms, `canvas_environment_unshaded` 4.3 ms, `canvas_water` 6.6 ms,
`canvas_capped_water` 12.1 ms, `water` 11.8 ms). The door was the first
place these appeared: the flame body chunk in an animating frame, and the
3.4 ms flame-receiver chunk when priming the first flame. The atlas owner now
lists its receiving and output shaders (`RECEIVING_SHADERS`), and Play
assigns those plus the environment, water, flame and modular source shaders
once in `_ready`. A worker-built flame texture array was tried and reverted:
it saved only the 0.29 ms upload.

### R5 — support cells captured with their first source (done)

The planner capture visited each needed support cell (1,131 for the door) in
its own preparation step after the last source. `_need_cell` now captures a
cell's owners and published height when a source first needs it. The capture
token still proves the atlas did not change, cell order is unchanged, and the
receiver set is still sorted by list index. Capture after construction fell
from 3.6 to 1.3 ms (3 → 2 frames).

### Result (interleaved, same window)

| Runs | Door world hold, per run | Median |
|---|---|---:|
| Current (`T014059`, `T014237`, `T014413`) | 265.8, 179.1, 197.9 | **197.9** |
| Committed `eff11fd` (`T014154`, `T014332`, `T014502`) | 275.5, 190.8, 221.6 | 221.6 |
| Earlier pair, before reverting the texture array (`T013122`… vs `T013215`…) | 224.1, 217.8, 160.0 vs 257.4, 247.2, 240.7 | 217.8 vs 247.2 |

The current code is faster in every pair. Door scene-thread work
72.7 → 61.6 ms (objects 16.5 → 10.7, flame priming 4.45 → 0.74), over
38 frames (24 held) instead of 43 (27). The only remaining over-budget chunk
is the first construction frame (5.5 ms: result adoption, atlas begin,
environment capture). Checks: live environment admission 36, world
preparation sparse 78, world atlas preparation 172 (native), world preview
10,079; the capture-related suites give the same results as `eff11fd`
(native atlas output sample 159, actor resource preparation 305; native light
capture, native atlas staged and receiver ownership are red or time out the
same way on both).

### Planner work is proportional to new content

New planner counters (`prepared_specs_*`) show what the door's 1,156 specs
are: 875 rows of the one floor batch, which grows from 9 to 884 rows; 220
single static sources; 58 actor layers; 3 retained neighbours whose support
mask changed. The move plans 369 new floor rows of a 1,253-row batch. No
unchanged row is re-planned. The planner costs about 50 µs of GDScript
bookkeeping per new receiver (records 15, plan specs ~7, spec copy ~6, canvas
item 4.5, projection 3.7, floor address 3.6). Its remaining wait, about 43 ms
after membership, cannot start earlier without breaking source-order
reservations: floor addresses follow every object's. Shortening it means
restructuring per-row records, which is not attempted under Stage 1.

Next on this path: the publication frame and construction work, and the
held-frame allowance decision (see Gate A status).

## Phase 2 — `main.gd` cut out of the live chain (done)

`play.gd` extended the workshop script `main.gd`, which loaded the workshop's
exploration, editor, walking, map, view-build and grid-renderer scripts into
the live game. An inventory of `main.gd`'s 137 members showed Play uses 16
variables/constants and two functions (`position_camera`, `pixel_selected`);
its six engine callbacks were all overridden without `super`. Those members
moved to `presentation/sprite_sources.gd`, which both `main.gd` and `play.gd`
now extend directly.

- `world_preparation.gd` drops its now-inherited `EnvironmentMedia` constant
  and renames a local `resources` that would shadow the inherited member.
- Four test fixtures that subclass `sprite_sources.gd` drop their redeclared
  `textures`/`resources`; one test reads the modular shader directly instead
  of `world.MODULAR_SHADER`.
- New `tests/live_chain_separation_checks.gd` (18 checks): loading `play.gd`
  loads neither `main.gd` nor its workshop-only scripts, and Play's base
  script is `sprite_sources.gd`. It fails on the previous commit.

Gates:
- live route 81/0;
- Studio replay 8,840, no failures, errors or warnings;
- actor 341 (native) and 305 (headless);
- environment source 25,877; world preview 10,079; world atlas 172 (native);
  native scene support 12,939;
- media streaming 50, shared residency 44, priority 34, optional
  selection 12, preparation admission 35, environment streaming 35, world
  preparation sparse 78, live environment admission 36.

Unchanged from the previous commit (already red there):
- native 2D source checks (18 script errors and a timeout);
- player effect picking (16 errors);
- modular tint;
- environment input state;
- reveal preparation overlap.

`selection_media_checks` needs a `--case` capture argument.

## Phase 3 — live interaction extraction (in progress)

Inventory (read-only, 17 October; `play.gd` 4,020 lines):
- 86 test files use the four exit-criterion names on Play instances (`session`
  55, `hud` 42, `context_menu`/`context_options` 36), so those names need test
  migration rather than forwarders.
- Five test subclasses override interaction methods.
- The HUD (`play_hud.gd`) makes 184 `world.*` accesses.
- The renderer's coupling to live code is in the media pipeline: selection
  hints in `_prepare_media`, `_publish_media_interest`, `_prioritized_media`
  and the live native-startup plan. The only render-path coupling is the hover
  reset after rotation.
- Per-frame order to preserve: session poll → prepared-operation drain;
  action responses → prepared advance; discovery/storage/hover after the draw
  sort; HUD bar before optional work.

Slices, one commit each:

1. **Native choice resources** moved from `component_renderer.gd` (shared with
   Studio) to `live/choice_resources.gd`. Play owns it; it takes the shared
   account explicitly (no private allowance). `native_choice_prefetch_checks`
   (10) migrated; live route 81/0; compact interaction and hover feedback
   unchanged (the latter already red).

Next slices (design from the inventory):

2. **Interaction controller** `live/interaction.gd`.
   - **Contents:** the choices, preview, command, receipt, hover, approach and
     storage members, with the functions that own them, plus the PopupMenu.
   - **Forwarding:** Play keeps typed forwarding properties for the duration
     of the migration, except for the four exit-criterion names (`session`,
     `hud`, `context_menu`, `selection_media`).
   - **Interface it gets from the world view:** picking (`pick_world(screen,
     force)`, `pick_cell`, `pick_actor`, a public identity hit), camera/view
     queries, `timeline`, readiness (`native_startup.ready`,
     `media_initial_ready`, `media_issue`) and an `invalidate_media_plan()`
     call.
   - **Per-frame order:** discovery, storage and hover run after the draw
     sort; action responses run before the prepared advance.
   - **Tests:** the five test subclasses that override interaction methods
     (compact interaction, hover feedback, live gallery, targeting native
     capture, targeting hover) are retargeted at the controller.
3. **Selection hints** `live/selection_hints.gd`. The world view's media
   pipeline reads an injected provider instead of the selection-media state:
   - the hint value and its onset paths;
   - a refresh hook taking the groups and media plans (for the hold-cursor
     release);
   - the live native-startup plan.

   Studio panes get no provider, so they allocate no `selection_media`.
4. **Live game** `live/live_game.gd`: session start and config/recording
   parsing, HUD creation, per-frame orchestration (poll, displayed sequence,
   ready/connection notices), teardown. Tests migrate from `scene.session`,
   `scene.hud` and `scene.context_menu` to the live game (86 files, mostly one
   `scene.session.close()` / `scene.hud.hide()` line each).

## Studio gate

`tests/studio_replay_native_checks.gd` (the plan's "full native Studio run"):
8,617 checks on `901340c` and 8,519 with the light-plane change, zero
failures, script errors or warnings. The count varies run to run because the
Invisibility loop checks once per frame and playback samples every 150 ms
(the plan's 8,686 was one such run).

Remaining shadow cost, attributed: shadow viewport resizes
(`state.viewport.size`) take 1–6 ms when an actor's shadow rect changes size
during a spell, one to four times in some frames. Avoiding them changes how
the visibility texture is addressed (render to a fixed-capacity target and
sample a sub-rect), so it needs its own capture qualification. Not done.

## Tests that were already failing at the checkpoint

Confirmed red with the original code (not caused by this work):

- `tests/media_role_race_checks.gd` (known from the handoff).
- `tests/media_demand_checks.gd` — calls removed `_same_demand()` and
  `_family_roles()`.
- `tests/preload_priority_checks.gd` — reads removed `estimate_summary`
  and `estimate_bytes` fields.
- `tests/creature_shadow_checks.gd` — modular Chest14 entry gets no component
  geometry from `CharacterGeometry.bind`; the test then hangs.
- `tests/shadow_source_checks.gd` — 36 × "Moving the selected native light
  beyond its footprint reranks immediately".
- `tests/native_light_cookie_checks.gd` — "Inactive native cookies have an
  exact bounded lifetime".
- `tests/world_preparation_receiver_ownership_checks.gd` — "One prepared
  dynamic receiver completes planning/binding without a worker scheduling
  frame" (timing-dependent).
- `tests/native_atlas_door_preparation_checks.gd` — worker canvas item,
  private RID binding and profile-field checks (230 checks, same failures on
  the clean checkpoint).
- `tests/reveal_preparation_overlap_checks.gd` — script error reading
  `worker_ms` in `_poll_actor_resources`; identical on `3e4d22e`.
- `tests/blood_world_preparation_checks.gd` — "Blood world preparation
  deadline" (exit 2); identical on `3e4d22e`.
- `tests/native_light_capture_checks.gd` — 17 script errors, "Changed
  admitted token rejects private prefix before worker publication";
  identical on `eff11fd`.
- `tests/native_atlas_staged_checks.gd` — exceeds a 400 s timeout on
  `eff11fd` as well.
- `tests/prepared_membership_checks.gd` — 4 script errors and a timeout,
  identical on `d990882`.
- `tests/presentation_checks.gd` — 2 failures ("HP commits exactly at
  authored contact/release", "contact exposes recorded HP after-value"),
  identical on `77ad0e6`. `tests/basic_condition_checks.gd` needs `--cases=`.
- `tests/targeting_hover_checks.gd` — needs a `--case=` capture argument
  and exits 2 without it (on `d990882` as well).
- `tests/native_spell_playback_checks.gd` — 6 failures (fire bolt and magic
  missile readiness), identical on `af3daa2`; `native_optical_media_checks`
  times out and `selection_media_checks` exits 2 on both.

One live run (`20261017T005810`) failed 2 of 78 checks: the second Fireball's
target click received its preview, but the client never sent the command
(`pending_kind=choices`). Command 4 in that run had a 666 ms server exchange.
The cause is not yet attributed. It has not recurred in 11 later runs and is
watched.

Passing after the Phase 1 changes: media optional selection 12, media
streaming 50, shared residency 44, publication priority 34, preparation
admission 35, shadow scalar 19, light projection 1,478.

## Gate A status (17 October, after `c006218`)

Three routes on `c006218` (`T041855`, `T041933`, `T042011`) in the slowest
machine window of the day: the committed baseline itself ran 25–50 % slower
than in the morning. Every change above is judged by interleaved pairs, not
by these absolutes.

| Criterion | Target | Now | Notes |
|---|---|---|---|
| Door hold | < 100 ms | 203.6 ms median | Every pair is faster than its baseline (R2–R5: 250 → 197 and 222 → 198 in matched windows). What remains: about 60 ms of scene-thread work at 2 ms per frame (~30 frames), the planner's ~43 ms wait (proportional to the 1,156 new receivers), and the ~32 ms publication frame. See D1 below. |
| Movement hold | < 100 ms | 0 ms median | met |
| Steady frame median | ≤ 10 ms | idle 10.0–10.1; animating 12.3–13.1 (Fireball 15.4–17.9) | Idle meets the target in a normal window (8.0–8.8 earlier). Fireball frames carry the spell's real per-frame work, plus 3–4.5 ms outside the script. |
| Spikes > 16.7 ms attributed, none from repeated work | all attributed | 229–272 per run, each labelled by `route_summary.py` | Repeated-work causes found today were removed (Phase 1 rows). Open, not repeated work: the media-readiness return cost (~0.24 ms) and shadow viewport resizes (1–6 ms). |

**D1 rejected by the user (17 October).** A hold is the display clock
waiting, so the door animation visibly pauses. The user: "there can be no
frozen frames". The goal is **no hold at all**, not a shorter or better-used
one. The revealed room must be ready before the door animation reaches its
cue: about 240 ms after the packet in these runs, against ~425 ms of
preparation today. Ways to close it:
- less scene-thread work (the 2 ms per animating frame budget is what
  stretches ~60 ms of construction over ~150–200 ms);
- more of that work on workers, published once;
- a shorter planner chain (derivation ~79 ms, planner ~58 ms);
- a lighter publication frame (~32 ms).

The 2 ms budget itself stays, because the door animation must not stutter
either.

### Stage 1 items still open

- Track N step 1: N1 (attack recipe deep copy: callers share nested recipe
  parts, so a shallow copy needs a mutation audit; attacks are not in the
  Gallery route, so it cannot be measured there), N11 (palette-range
  freshness scan: bake ranges into the body-source importer; compile-worker
  cost only), N7/N8 (startup document reads to a worker; startup only), N12
  (PNG header reads now already run on workers).
- §5.5 item 6 (one account): every live caller passes the shared account. The
  remaining defaults serve Studio's blood thumbnails (`thumbnail_cache.gd`)
  and several test harnesses; a Studio-side owner is needed before deleting
  `_native_budget`/`_prepare_budget`.

## Afternoon, 17 October (after the atlas deletion)

The afternoon runs shared the machine with an unrelated pytest job at 100 %
CPU; absolutes drifted up by about 40 % across unrelated changes. Each change
below is judged by its own phase maxima or by byte-identical captures, not
by route medians.

| Commit | Change | Evidence |
|---|---|---|
| `b803a81` | Sampled actors use an arithmetic clip clock (no AnimationPlayer/Tree per actor). | Equals the seek tree bit for bit for every clip of every rig (`runtime_retention_checks`). Door `actor_graph` 5.4 → 0.26 ms. |
| `5350223` | Rotation prepares the target quarter's native floor receivers. | Native effects were not ready from q1 on; now ready in all four quarters (check added to the publication harness). |
| `7fabca9` | Sprite quads shared by shape; shape changes swap the mesh. | A worker-built node with its own QuadMesh costs ~6 µs to attach, shared ~1.4 µs. Door objects 6.2 → 4.4 ms. |
| `c89efaa` | Retained entries leave a retiring view root at rotated publication. | Studio reverse seek freed displayed terrain nodes; `studio_hide_render` now completes the seek (808 → 985 checks). |
| `b1fc64d` | Lights awaiting preparation are pending, not presentation errors. | `fireball_layer_ownership` 25/0 (was 25/1); `native_spell_playback` 1911/2 (was 1871/6). |
| `8548532` | New actor layers join the spell receiver boundary. | Agent report item 2. |
| `667db0e` | Blood lights itself from the light table; its two full-screen PointLight2D pages are gone. | Light projection max 9–10 → 0.5 ms. All 29 `studio_blood_residue` captures and the gate's game views byte-identical. |
| `7994a38` | One texture per receiving global; retired view tables and decoded images freed on a worker; optional work waits a frame after a heavy frame. | Replacing a global texture re-queued every material (~10 ms). View retirement max 14.6 → ~2 ms; image release 5.8 → 0.14 ms. |

### Door critical path (run `T125712`)

Packet at 164 ms → source-only cut prepared at ~197 ms → static forecast
derivation on a worker until ~263 ms → construction 271–393 ms → membership,
scenery and sort until ~423 ms. Construction is main-thread bound: 16 frames
at the 2 ms budget, 22 ms of world work and 9.5 ms of texture handoff. The
room was ready before the cue in these runs (world hold 0 in most). Per item
on the main thread: ~37 µs per actor layer (24 µs completing late textures),
~25 µs per object, against ~1.4 µs for the attach itself.

### Packet → first animation

About 40–55 ms happen off the main thread before the group exists. A move
packet is 347 KB: JSON 9.7 ms (str_to_var fast path), reducer 15.6 ms
(sensory facts 9.1 ms), compile 7.5 ms. Packet size is server-side.

### Texture uploads (open, L8)

A Gallery run uploads ~900 sheets of 1920×1024 (~7 GB). Most cost ~0.4 ms,
but about 1 % take ~10 ms (allocation), and any main-thread RenderingDevice
call waits for them: a 16 KB light-table update was measured at 2–8.5 ms.
Serializing worker uploads, main-thread uploads and a 512 MB staging buffer
were each tried and did not help. Crop-and-pack into preallocated page
arrays (L8) removes allocation during play and cuts the bytes 25–35×.

### Spike attribution (three contended runs)

194 script spikes and about 50 engine-side stalls. 146 of the script spikes
are Fireball frames (`actor_sample`/`component_sample` 4 ms,
`session_timeline` 3.5 ms on average in a spike). A Fireball frame is
~7.5 ms of script at p50, spread over many 0.4–1.4 ms parts.

### Known failures checked against the previous commit (same on both)

`studio_blood_residue` (2: field allocation pacing), `impact_placement`
(null socket attachment), `condition_pose` (recording decode),
`character_geometry_render`, `receiver_bounds` (fixture), and
`actor_preparation` (fixture lacks `source_sample`).
`native_spell_playback` keeps 2 failures: blood fields are never prepared for
a restored residue tile.

## Evening, 17 October: plan steps in progress

User direction: do the plan's remaining big steps first; media size (L8) after, but
it stays required (sheet loading also causes in-play hitches). Sprite-sheet
effects without a native version are dropped (user, 17 October): they show
nothing until an artist agent authors Factory VFX.

Work split: the lead agent takes L5 and the L1 door path on
`feature/opus-refactor`; agents work in their own worktrees and branches:
L4 shadows (`feature/opus-L4`), L6 blood fields (`feature/opus-L6`), L7
effects plus the legacy sprite-effect deletion (`feature/opus-L7`), L3 draw
order and ground overlay (`feature/opus-L3`). Measurements from this window ran
beside those agents and an unrelated CPU job (idle frame ~9 ms instead of
~4.6 ms); only counts, phase splits and byte-identical captures are used.

| Commit | Change | Evidence |
|---|---|---|
| `f77f83d` | Encounter preload: selected light profile only; inactive weapon-set gear at rest only; clips outside the rig skipped. | Gallery plan 2,555 files / 18.7 GiB -> 1,825 / 13.4 GiB. A run uploaded 1,758 sheets of 1920x1024 and displayed 356 before the change. |
| `5ff3442` | Live clip changes bind in sampling (no source-only world cut). | Room preparation now starts ~20 ms after the door packet (was ~100 ms, behind the source cut). |
| `4efffa8` | Actor track samples computed once per displayed instant. | Gate identical. |
| `347dcc5` | Effect-layer changes (e.g. Fireball's Magic2) build in sampling; the group's later cut media load early. | No world waits at Fireball start. Exposes the projectile's native readiness ~70 ms into the group (handed to L7). |
| `76bff4c` | Construction lanes stop re-polling when everything waits. | `actor_layer_blocked` (2.9 ms per door) gone. |
| `3df7580` | Object lane adopts ready worker rows in one pass. | Fewer turns per row; operands identical (33,833 checks). |
| `2d5fdf5`, `edb9379` | Preparation allowance rises before a world's cue (3 ms within 300 ms, 4 ms within 150 ms, 8 ms once held); fixes the optional-skip regression that also skipped the next world's preparation. | Door construction 21-22 -> 13-15 frames under the same load. |
| `8ba8993` | Static derivation prepares environment row sources in parallel chunks. | `sources` worker phase 16 -> 12 ms on a ~35% slower machine. |

Door, current window: room preparation starts at the packet; derivation
65-90 ms on a worker; construction 13-15 frames; the room still misses the
cue by ~50 ms under this load. The publication frame is dominated by shadow
updates (L4), draw sorting (L3), timeline state apply (~1.3 ms) and wall
visibility (~1.1 ms).

## Night, 17 October: merges and baked spell effects

| Commit | Change | Evidence |
|---|---|---|
| `c698883` (L4) | Shadows: change detection, no cookie readback, fixed helper targets (no resize in play). | Gate 0 failures; primaries differ only by 4-31 shadow pixels at 1/255 (accepted). |
| `e238ad2` (L7) | Native construction without GPU readback (15-19 -> 1-4 ms); spell passes warmed; Studio swatches parked; sprite-sheet condition effects deleted; native receiving pages lit by the light table. | Gate 8,883/0; only the Haste and See Invisibility sprite pixels change. |
| `25cb447` | Baked native effects (recorded particle states) for static clips; actor receiver proxies never deferred. | `baked_effect_checks` 178/0; live route 81/0. |
| `8b4db36` | Baked moving projectiles (path-placed particles, path trails); one-file-at-a-time loading with per-frame texture creation; canonical clip hashes. | `baked_effect_checks` 187/0; three live routes 81/0, no stale fallbacks. |
| `0e8d882` (L3) | Draw order: moving draws keep ranks in gaps between statics; work only on change; shared route material. | L3: order oracle 118,098/0 over 44 journals; idle `draw_order` 0.265 -> 0.074 ms. |

Fireball (live route, Fireball portion, same machine as the native runs):
effect sampling 0.29-0.33 -> 0.18-0.19 ms per frame; no mid-cast freeze (the
43-114 ms holds were gone after L7); remaining waits are one frame at cast
start, from the spell pass's floor receivers being rebuilt when the ground
batch changes (budgeted GDScript loop). Contract and guidance:
[NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md](NATIVE_VFX_RUNTIME_CONTRACT_2026-10-17.md).

Studio load time (measurement agent): the "Preparing 4.7 s" text is the
recording position, not elapsed time. A cold Studio launch to the first case
is 4.2-5.2 s (engine 1.0, GDScript compile 1.9-2.3, `Recording.read` 1.0-1.1
with a GDScript JSON parser 7x slower than Godot's, media plan 0.3); a case
switch 1.1-1.7 s with a 40-130 ms main-thread free of the old index. Fixes are
in progress on `feature/opus-load`.

Open: floor receiver rebuild wait at cast start; bake the remaining spells and
add the bake to asset preparation; Fire Bolt's flight (CPU Trail3D) stays
native; L5 and the door path; L8.

### Later the same night (18 October, early)

| Commit | Change | Evidence |
|---|---|---|
| `6c4b601` | Spell pass floor receivers: one buffer write, never deferred. | native_floor_batch 267/0, native_scene_support 11,600/0 (byte parity, same as before). |
| `3986abf` | Whole spell catalog baked (64 of 72 clips); fixes from the visual review: hash without `source_identity` (index rebuilds made every recording stale), override materials not overwritten (Burning Hands black), bone poses recorded, emitter-less clips, standard-material tracks; Chill Touch's impact rejected (plays native). | Gate 8,878/0 with baked effects; native spell tests identical with and without baking. |
| `fafb382` | First frame of an action without a held frame: compiled groups and the opening media plan reach the scene together; audio never gates the picture (late voices start at their offset). | Live routes 81/0: no held first frame on move, drink or Fireball (was one per action). |
| `693a694` | Baked loading: first variants first, extra variants only between actions; fixes a clip marked unrecorded while its textures were still being created. | baked_effect_checks 133/0; startup checks 29/0 and 156/0. |

Known differences for the VFX agent:
[FACTORY_VFX_BAKING_REPORT_2026-10-17.md](FACTORY_VFX_BAKING_REPORT_2026-10-17.md).

Client latency (packet to first animated frame, three clean routes before
`fafb382`): door 83–87 ms, move 60–72, Fireball 40–49 (server answer:
door 133–150, move 91–136, Fireball 450–750 in `execute_action`; server work
is owned elsewhere). Breakdown for the door: parse 19–21, reduce 19–21
(sensory facts ~9, world ~7), compile ~15, ready to screen 23–27. Reduce and
compile are being cut on `feature/opus-latency`; Studio load time on
`feature/opus-load`.

Open: the door's remaining holds (room late at the cue: L1; sprite sources:
L8); Fireball's first cast waits one frame for a native source; first-draw
pipeline compiles show as 30–45 ms frames outside the script under load.

## Session close (18 October): merges, quiet-machine route, what is left

Everything is on `feature/opus-refactor`; every `feature/opus-*` agent branch
is merged into it (none has unmerged commits). `codex/ndclient` is untouched
(user: keep the work on the branch).

| Merge | Change | Evidence on the merged tree |
|---|---|---|
| `fd9c09c` (load) | Studio case switch: old index freed after exit, record decode once, catalogs parsed once per process, native strict journal parse. | Case switch 0.95–1.55 → 0.54–1.12 s; switch hitch 92–157 → 28–48 ms. |
| `371b81c` (latency) | Reducer, transitions, compiler and audience cut per packet. | Door reduce 15.0 → 9.6 ms and compile 12.6 → 2.3 (agent, same journal); `packet_pipeline_equality_checks` 1,257/0 over three live journals and the defaults; SDK suites 0 failures; gate 8,904/0. |
| `7dbb3c2` (L8 phase 1) | Offline sheet prepack into 128² page bundles; no runtime change yet ([L8_SHEET_PREPACK_2026-10-18.md](L8_SHEET_PREPACK_2026-10-18.md)). | `sheet_prepack_checks` 1,462,841/0 over 359 bundles; all 359 clips load and upload in 0.40 s against 16.9 s for PNG decode and upload; 277 MB of textures against 10.6 GB. Disk: the zstd-compressed bundles are 68.7 MB against 82 MB of PNGs (1.5 ms per clip to load; the raw variant is 429 MB and 1.0 ms). |
| `ba2da1f` (L1 stage) | Door cue: a boundary commit within the commit tolerance publishes at its authored time (a rounding below it changed the preparation key and rebuilt the finished room: 12 held frames in 2 of 5 replays); the cue reuses the previewed candidate; staged tiles indexed by admission time. | Gate 8,883/0, primaries as accepted; order oracle 43,667/0; `world_boundary_rounding` 7/0 (4 failures before the fix); world preview, preparation gate, timeline world changes, Studio prefix and precision checks 0 failures. Door replay cue frame script 18.6–25.8 → 17.3–17.7 ms. |
| `9ac9e20` (VFX package) | Spells play the Factory package `assets/vfx/` (`presentation/effect_package.gd`): recorded approach by default, GPU or native on request (`-- --effect-kind=`, Studio Inspect → Effect version). Client baker, copier and baked bundle deleted. Staging is still the client's, through `.derived/native-spells`. | Gate 8,869/0, primaries as accepted; order oracle 43,145/0; `effect_package_checks` 1,048/0 (55 clips, 217 approaches); `studio_effect_version_checks` 32/0; `vfx_effect_hold_checks` 10/0; spell lifecycle times 768/0; Shield reaction 58/0. Effect construction max: Fireball 24.2 → 1.0 ms, Gallery 19.1 → 0.97 ms (agent, back to back); the Gallery replay no longer stalls at 5.87 s waiting for a spell effect. |

Gate primaries on the merged tree are the accepted set: baked-effect
differences in `hide-mid` (212 px) and `invisibility-seed3-v2-end` (242 px),
shadow rounding elsewhere (≤ 31 px at 1/255).

### Quiet-machine route (three runs, `20261018T002837`, `T002918`, `T003012`)

No agents and no other Godot running; all three 81/0, no script errors.
Client time is packet to first animated frame; server time is not included.

| Action | Packet → first animation (median, range) | Held frames (world / media) | Frames > 33 ms |
|---|---|---|---|
| Door open | 61 ms (56–63) | 0 / 0 in all runs | 0 (max 20–28 ms) |
| Move into the big room | 50 ms (49–75) | 0 / 0 | 0 (max 19–23 ms) |
| Drink | 25 ms (24–25) | 0 / 0 | 0 |
| Fireball, first cast | 49 ms (48–66) | 0 / 1 in one run | 1 in two runs (pipeline compile, 36–43 ms) |
| Fireball, second cast | 51 ms (33–57) | 0 / 0 | 0 |

Door split: parse 18–24, reduce 15–16, compile 4–5, ready to screen 12–18.
Before this session's latency work the door was 83–87 ms, with a held first
frame on every action. Idle frame p50 7.2 ms, p95 9.9.

### Known failures (checked, not from this session)

- `studio_seek_checks` on the Gallery route journal (`.runtime/gallery-route/journal`):
  "sampled movement keeps its recorded heading 96:a429c263…:0". Same on
  `7faf78f` (the commit that added the test), on the pre-latency base and with
  the L1 timeline reverted. The test's reference journal set passes on the
  merged tree (6,339/0).
- `presentation_staging_checks` "captured packet decodes" (fixture input);
  same on the L1 base commit.

### What is left, in order of payoff

1. **Door, first draw of the new room:** the frame after the cue is 18–21 ms
   with ~5 ms of script (draw calls 51 → 370, one pipeline specialization).
   Shared per-record materials (the L1 static renderer) or warming the room's
   pipelines before the cue.
2. **Door, cue-frame static work** (~17.5 ms of script in the replay):
   `world_sync` ~4.1, modular shadows 2.6–2.9, draw order 1.9–2.6,
   wall visibility ~1.1; move it before the cue. Main-thread construction
   (~19 ms over 15 frames in the replay, ~53 ms under live load).
3. **Parse and reduce** are now most of the door's client time (~35 of 61 ms).
4. **Fireball first cast:** one pipeline-compile frame (36–43 ms) and an
   occasional one-frame media wait.
5. **L8 phase 2:** runtime reads the zstd sheet bundles (design in the L8
   doc); the VRAM target stays after speed.
6. **VFX** (for the Factory agent): clips still native and the known
   baked/native differences are in
   [FACTORY_VFX_BAKING_REPORT_2026-10-17.md](FACTORY_VFX_BAKING_REPORT_2026-10-17.md).
