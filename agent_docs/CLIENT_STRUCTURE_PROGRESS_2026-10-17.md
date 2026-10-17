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

### S2 — remaining spikes after Phase 1 (open)

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

One live run (`20261017T005810`) failed 2 of 78 checks: the second Fireball's
target click received its preview, but the client never sent the command
(`pending_kind=choices`). Command 4 in that run had a 666 ms server exchange.
The cause is not yet attributed. It has not recurred in 11 later runs and is
watched.

Passing after the Phase 1 changes: media optional selection 12, media
streaming 50, shared residency 44, publication priority 34, preparation
admission 35, shadow scalar 19, light projection 1,478.

## Gate A status

| Criterion | Target | Now |
|---|---|---|
| Door hold | < 100 ms | 197.2 ms median in the slow window (committed code 250.0 in the same window; 198.6 → est. ~155 in the earlier fast window) |
| Movement hold | < 100 ms | 0 ms median (bimodal; one baseline run 1,319 ms) |
| Steady frame median | ≤ 10 ms | idle 7.98 ms ✓; animating ~10.5 ms |
| Unattributed frames > 16.7 ms | none | ~170 per run, attribution in progress |
