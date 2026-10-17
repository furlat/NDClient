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

Next: overlap per-source group material creation with construction so the
planner no longer starts only after the last object; derivation phases that
depend only on rows (support, visibility, walls) can overlap routing.

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

Passing after the Phase 1 changes: media optional selection 12, media
streaming 50, shared residency 44, publication priority 34, preparation
admission 35, shadow scalar 19, light projection 1,478.

## Gate A status

| Criterion | Target | Now |
|---|---|---|
| Door hold | < 100 ms | 198.6 ms (median) |
| Movement hold | < 100 ms | 0 ms median (bimodal; one baseline run 1,319 ms) |
| Steady frame median | ≤ 10 ms | idle 7.98 ms ✓; animating ~10.5 ms |
| Unattributed frames > 16.7 ms | none | ~170 per run, attribution in progress |
