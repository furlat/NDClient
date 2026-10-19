# Prepared appearance provider — 19 October 2026

This implements Phase 4's **appearance** slice using real Fly as the first proof. It does not complete created-item art, actor history, all condition treatments or the performance gate. Approved lighting, normals, colours, cap, shadows and wall tuning are unchanged.

## Data and ownership

`PresentationCondition.appearance_layers` is typed authoring. Fly's existing Bag8 assignment moved from the unported bag into this field. The normal abilities build writes it into the condition recipe and rejects conflicting semantic definitions during the build. No runtime schema/hash validation was added.

`condition_appearance.gd` projects the actual ordered condition owners into physical outfit membership. The compiler/media planner prepares the required sheets at application, including a condition admitted midway through the current casting clip. Equal physical source art remains shared. Native layer construction and publication use the existing world preparation owner.

The delivered Factory appearance setter receives a per-condition proxy. Its lease retains the real condition UUID, actor UUID and authored layer identity. It controls only opacity; the body owns clip/frame/facing and the current canonical equipment. Unchanged bindings keep their lease. Only eligible, successfully sampled native handles contribute opacity in that frame; stale invisible, dead or failed handles contribute zero. Matching overlapping owners use maximum opacity, and removing one owner cannot clear another owner's lease. Distinct definitions compete by authored priority with stable identity.

Removal retains the layer through the actual Factory fade, then prepares the current authoritative outfit. It does not restore saved old equipment. The exact endpoint is also planned when it falls during idle with an empty queue or between operations. That candidate has no synthetic group or commit, changes no authoritative cursor, and advances only the existing display clock. Future canonical state remains undisplayed.

Studio now exposes the physical appearance operation alongside the body and native VFX. The ordinary layer thumbnail uses the actual sheet/current body pose; it is an asset preview, not a simulation of Factory opacity. The track identifies the Factory opacity lease, and the event trace requires an actual visible lease sample before rendering is witnessed. Source availability, runtime presentation, final pixels and user approval remain distinct.

## Failures found with real playback

1. **Application while casting:** the former media closure overwrote physical appearance membership with cast overlays and failed to request Bag8's current casting sheet. Preparation now preserves physical layers and adds the actual clip at the admission cut.
2. **Removal during idle:** the recorded concentration drop ended at 5166.666667 ms, the Factory fade ended at 5316.666667 ms, and the next operation began at 5516.666667 ms. The old group-only planner skipped that interval. Shared idle/replay/lookahead planning now admits the exact retained-owner endpoint without inventing an event or holding the presentation clock.
3. **Cancelled worker output:** a resource worker could finish a detached layer Node before adoption. Retirement/exit owned only nodes already attached to the candidate. The preparation owner now retires unadopted worker nodes and preserves nodes already adopted by a displayed actor. This removed the observed orphan MeshInstance3D and its mesh/material/texture/resource shutdown errors.

Earlier failed attempts are retained in `.runtime/condition-appearance-native{,-2,-3,-diagnostic,-4,-verbose}.log`; none is counted as a passing gate.

## Real scenario and evidence

`spell.fly/lifecycle` uses original schema16 Amber/Blue server journals under `.runtime/studio-library/cases/spell.fly__lifecycle/20261019T171024.108231Z/`. The player casts Fly on itself, moves, unequips a cloak, ends a turn, re-equips the cloak, moves, actually ends concentration, then moves after removal. There are 22 recorded operations. The library now contains 198 cases; no journal was translated or rewritten.

- `condition_appearance_checks`: 39 checks, clean. Covers typed membership, current cast media, preparation privacy, exact fractional endpoints in active operations/idle/empty queues, cursor preservation, current-gear restoration, build conflicts, real Factory leases, inactive sampling and overlapping owners.
- `actor_resource_preparation_checks`: 302 checks, clean. Includes actual production-owner cancellation, unadopted cleanup and adopted-layer preservation. Its old fixture had equal-depth transparent ordering ties; the fixture now assigns canonical layer sort offsets to both compared paths. Production draw ordering did not change.
- Native Fly replay before the last Studio inspection addition: 2878 checks, zero failures, script/engine/resource errors or warnings. Four actual camera views, visible wings, moving pose/frame agreement, authoritative gear, independent faction journals, seeking, exact final prefix and automatic looping are included. `.runtime/tests/20261019T172745Z/condition_appearance_native_checks.log` and `.runtime/condition-appearance-native.json`.
- Final native Fly/Studio regression and five repeated live equip runs: qualification is recorded in the current progress ledger after the code freeze. Earlier numbers do not qualify later edits.

Actual primary/studio images are under `.captures/studio/replay-comparison/spell.fly-lifecycle-*`. Four-view captures were inspected; this is functional integration evidence, not human acceptance of all artwork. Native functional frame intervals include oracle/capture work and are not performance measurements.

## Remaining scope

Unsupported fixed-creature outfits have no invented Bag8 substitute. Flame Blade still lacks its real worn-item art. Actor history/capture, event streams, remaining material/body handovers, adaptive family variants, short-queue first-use readiness and final gameplay performance remain open in the main plan.

## Metadata worker ownership found by the live gate

The first post-cohort live set is deliberately retained red at `.runtime/schema16-appearance-post-cohort-equipment/report.json`: run 1 was interrupted by the test runner's overly broad cleanup, run 2 emitted 2,986 invalid metadata-task errors, and runs 3–5 were clean. These are not five passing independent runs.

The runner's final cleanup now filters selected script paths as its per-test cleanup already did. It leaves a separate preview or different active test in the same worktree alone. This was verified with independent headless/live/preview process records; subsequent actual live runs are separate evidence.

Temporary task tracing reproduced the metadata failure in `.runtime/player-runs/20261019T174038.987175Z/godot.log`: metadata task 178 was created at frame 28 and was already invalid when polled, before its metadata owner joined it. The trace does **not** prove which underlying loader/pool operation invalidated the handle. A plain concurrent-resource micro-reproduction did not reproduce it, and a traced Crypt run was clean. All tracing substitutions were restored from exact pre-instrumentation source before qualification; no trace wrapper is imported by production code.

Native Resource metadata now runs on one explicitly owned Godot `Thread` per media consumer. Existing pool-based decode, selection, geometry and world jobs are unchanged. A running required/optional job keeps its exact result/cache; newer requests queue normally. Poll detaches the completed thread/result before `wait_to_finish`, publishes the actual result and starts the next required request. Close detaches/joins once and clears pending intent. No stale-ID checks, job recreation, swallowed errors or runtime validators were added. The resource-loading lane remains asynchronous and bounded; this avoids its dependency on the invalid pool handle rather than claiming the underlying pool invalidation is diagnosed.

`media_native_worker_checks` passes 8 checks on actual schema16 native source closures, queued order, repeated idle polling/close and active shutdown. Current metadata consumers/test hooks use `plan_thread`. The historical metadata-handoff/latency checks still need their external recorded-state arguments; the older demand-precompute test references removed APIs and remains an explicit migration failure. It is not replaced by a fabricated passing fixture.

## Final code-freeze qualification

`.runtime/schema16-appearance-thread-qualified.json` records **13,937 passing checks and zero native/script/resource/engine errors** after the Thread ownership change and Studio appearance lane:

- Five independent actual Crypt player sessions: **170 checks**, ten equipment transitions, zero world/media holds. `.runtime/schema16-appearance-thread-qualified-equipment/report.json`.
- Eight existing real Studio cases: **10,783 checks**. `.runtime/schema16-appearance-thread-qualified-studio.{json,log}`.
- Actual Fly lifecycle: **2,984 checks**, four camera views, current outfit/frame/equipment, independent faction selection, seeking, ordinary playback, visible movement and automatic looping. `.runtime/schema16-appearance-thread-qualified-fly.{json,log}`. Its Studio appearance track now links the same condition/layer identity as the actual renderer witness.
- Final selected headless batch: **19 tests**, zero failures/script/engine errors, exit 0. `.runtime/tests/20261019T174538Z/summary.json`. This includes the new metadata Thread ownership gate. Shared private actor-resource parity/cancellation: **302 checks**, clean, `.runtime/tests/20261019T173736Z/actor_resource_preparation_checks.log`.

Six ObjectDB warning lines remain: one instance in native8 and 100/98/101/93/94 instances in the five live exits. Fly has no exit warnings. These are not suppressed or presented as a wholly leak-free application. All owned launchers, backends and Godot test processes closed.

These are functional gates; their timings include test assertions/captures and do not qualify steady game/Studio FPS, first-use latency or every spell/condition provider. The full old fast-suite migration failures remain documented in the main ledger.

## Main publication

Implementation `04b35df8` is published on main `codex-authoring-schemabump` with the matching abilities build and original Fly case/index (198 cases). Main actual qualification is 3,033 native/headless checks plus 34 real live player checks, zero errors; equipment crosses both boundaries with zero holds. Main artifacts are `.runtime/tests/20261019T175055Z/` and `.runtime/tests/20261019T175218Z/`. The live ObjectDB exit warning remains; the native Fly gate is warning-free. Recoverable prior build/index and receipt are in `.runtime/schema16-publication/appearance-20261019/`. All owned tests/backend processes closed.
