<!-- Fixed run evidence. Later results are recorded separately below. -->
# Door and movement readiness: measured decomposition, 16 October 2026

No production edits or Godot runs. Each source profile/trace JSON was loaded once by `.runtime/reveal_wait_decomposition.py`; detailed evidence is in `.runtime/reveal_wait_decomposition.json`. Timers describe elapsed work on the named thread, not OS sampled CPU. Children are not added to parents.

## Committed checkpoint `461bd07`: the reported 706 / 400 ms

| Action | Baseline media + world wait | Final media + world wait | First animation, baseline → final | Reveal frame, baseline → final |
| --- | ---: | ---: | ---: | ---: |
| Door | 344.108 + 598.946 = 943.054 ms | 306.073 + 399.536 = 705.609 ms | 227.522 → 210.915 ms | 44.145 → 30.292 ms |
| Movement | 81.327 + 223.036 = 304.363 ms | 76.259 + 324.186 = 400.445 ms | 225.000 → 225.693 ms | 31.018 → 28.907 ms |
| Fireball 1 | 11.014 + 15.367 = 26.381 ms | 39.305 + 44.762 = 84.067 ms | 1996.791 → 2009.148 ms | 22.479 → 24.128 ms |
| Fireball 2 | 0.000 + 22.932 = 22.932 ms | 16.449 + 23.496 = 39.945 ms | 1606.989 → 1648.103 ms | 29.408 → 27.704 ms |

Door holds improve 237.445 ms (25.2%); movement holds regress 96.082 ms (31.6%). Both remain above the requested minimum. Fireball holds also regress in this run, despite similar/better publication frames; no claim of unchanged Fireball latency.

## Checkpoint world hold: actual preparation versus wall time

Wait intervals are sampled phase transitions. The table clips process intervals to each world hold and labels by phase at interval end. “Reveal sample” includes the completed publication frame, not another preparation job. Uncovered tail is time after the final profile sample and before the observed gate release.

| End-sample phase | Door held wall | Movement held wall |
| --- | ---: | ---: |
| actors | 5.141 ms | 0.000 ms |
| membership_objects | 7.435 ms | 0.000 ms |
| scenery | 6.139 ms | 0.000 ms |
| scenery_styles | 5.835 ms | 0.000 ms |
| atlas_receivers | 192.982 ms | 175.998 ms |
| atlas_prefix_capture | 27.903 ms | 32.951 ms |
| atlas_prefix_wait | 18.137 ms | 15.937 ms |
| atlas_prefix_bind | 82.944 ms | 63.822 ms |
| sampling | 7.455 ms | 0.000 ms |
| Reveal sample | 30.292 ms | 28.907 ms |
| Uncovered observation tail | 15.273 ms | 6.571 ms |

The atlas receiving/capture/bind lanes consume **112.925 ms** door and **66.077 ms** movement of scene-thread preparation elapsed work. These are real work totals, not additional wall waits. They occupy 53 and 32 frames respectively under the existing 2 ms allowance. Their sampled intervals occupy 303.829 ms and 284.534 ms, plus 18.137/15.937 ms of worker planning. There is effectively no spare allowance in these lanes. Merely moving more publication work into this lane cannot produce <100 ms; its native work must be reduced/reused/batched or completed earlier.

## Source and construction overlap

- Door construction changes from 80 frames / 72.762 ms charged world work to 57 frames / 79.933 ms. Unused allowance falls from 39.807 to 2.253 ms: the former idle opportunity is used, but native work itself is not yet reduced.
- Movement constructors take 29.424 ms across 21 frames (baseline 28.083 ms / 19 frames). No missing-source deferral was recorded in the final movement constructor lane; this is real construction and scheduling, not a new source fence.
- Completed-source publication lag (worker upload finished → end of publication frame) is median 16.244 / p95 44.716 ms for final door, versus 13.194 / 50.522 ms baseline. This is an upper bound containing the publication frame itself.
- Final door has 13 construction frames with no image publication, >=1.9 ms world work, and a plan-missing image already completed before frame start. Some occur before the future cut is due; they must not all be labelled required-source starvation. The trace does not serialize exact per-path due priority.
- Final diagnostics preserve the last source deferral and can remain after resolution. Frequent missing records include modular Idle optical companions and the animal-statue colour/body mask. They do not prove that each later phase is still blocked.

## Worker decomposition

| Worker phase | Door | Movement |
| --- | ---: | ---: |
| rows | 18.315 ms | 13.867 ms |
| support | 6.501 ms | 5.694 ms |
| visibility | 3.036 ms | 4.416 ms |
| routing | 13.306 ms | 17.747 ms |
| ground | 9.356 ms | 13.009 ms |
| sources | 9.051 ms | 4.778 ms |
| walls | 7.223 ms | 11.341 ms |
| actors | 35.715 ms | 0.904 ms |
| blood | 3.424 ms | 4.314 ms |
| lights | 0.197 ms | 0.237 ms |
| source_snapshot | 0.068 ms | 0.091 ms |

Worker totals are 123.636 ms door / 91.803 ms movement, including atlas planners (not added again). Named children + planner leave only ~1.003 / 1.924 ms unlabelled. Main-thread world polling/admission is separate.

## Work and view-scope evidence

- Exact workloads match: door 1,003 placements / 317 draws / six actors / 279 atlas sources / 1,156 specifications; movement 1,464 / 515 / six / 199 / 593. Door has the same 54 UV changes, now zero outfit validations. No geometry/actor omission accounts for the improvement.
- `EnvironmentMedia.row_paths` enumerates all four views while native row construction selects the current quarter. Final gate snapshots contain all four directional geometry paths for winged statues and alchemy benches; movement contains all four for benches and pottery. The trace records 32 unique missing directional geometry paths during door holds and eight during movement holds.
- **Exact unused-view count is unavailable**: current-quarter per-instance closure is not serialized. Different instance orientations can legitimately need different paths, and colour atlases can physically share all views. Filenames alone are insufficient to claim three quarters are waste. Root can compare the already produced current-quarter `_row_sources` map with all-view environment requirements; no new runtime validator is needed.

## Causal priorities within the existing plan

1. Correct source scope at its producer and prioritize exact pending-cut operands; retain full later-view sources as optional interest, not a publication prerequisite.
2. Reduce the scene-thread receiver/capture/binding work; the measured 112.925 / 66.077 ms cannot fit the latency target merely by rescheduling at 2 ms per frame.
3. Preserve source/constructor overlap and exact final gate. Further broad preparation must not steal completed due-image publication or introduce same-frame admission poisoning.
4. Qualify actual movement and both Fireballs as controls. The saved final run alone does not meet those regression goals.


## Later regression: 19:02:18 → 19:16:24 UTC

Sources: `reveal-baked-fixtures-live-analysis.json`, `reveal-worker-construction-live-analysis.json`, their complete recorded profiles and media-gate traces. The JSON companion records exact phase/queue/leaf observations and lists input files; each input was decoded once in that analysis process. No live process or production edit was used for this report.

| Client readiness hold | Prior | Current | Change |
|---|---:|---:|---:|
| Door media |84.943 ms|157.145 ms|+72.202 ms|
| Door world |348.668 ms|507.193 ms|+158.525 ms|
| Door total |433.611 ms|664.338 ms|+230.727 ms|
| Movement media |73.203 ms|58.846 ms|−14.357 ms|
| Movement world |0 ms|227.547 ms|+227.547 ms|
| Movement total |73.203 ms|286.393 ms|+213.190 ms|

The CPU timers measure elapsed inside scene/worker functions, not OS thread CPU. Worker and main-thread values overlap; they must not be added to wall holds.

## Mandatory work actually improved; competing work grew

Across construction frames the door's main world work falls **140.946→129.274 ms**, while source-publication elapsed rises **41.010→96.383 ms**. The current route has 80 explicitly recorded background-handoff frames accounting for 79.466 ms of source publication. In the narrower door world hold, world elapsed falls **97.875→84.630 ms**, but source publication rises **14.226→68.019 ms**. The source operation takes the same two-millisecond frame allowance: atlas capture expands from 7 to 12 frames despite almost unchanged world CPU (16.197→16.423 ms), and final binding expands from 7 to 14 frames (14.198→17.914 ms).

Movement world construction falls **73.434→59.707 ms**, but source publication rises **14.165→60.415 ms**, with 48 background frames accounting for 49.162 ms. Main object construction begins at 300.605 ms after click instead of 235.156 ms. The candidate finishes around 834 ms instead of around 589 ms; it misses a final cut that was already prepared before. Its world hold is therefore new delay, not additional server execution.

One completed-source handoff currently calls `Media.poll(..., false)`, which also prepares optional source selection and dispatch. It is not intrinsically a constant-time pointer adoption. Background progress is necessary to prevent finite completed batches blocking future decodes, but admitting it on every construction frame consumes the mandatory world's allowance. That broad competition needs ownership/scope correction, not a faster local upload setter.

## Native constructor result

Door object constructor elapsed **36.946→18.157 ms**, and movement **24.544→6.933 ms**. The finite environment resource task costs **8.175/6.755 ms** on its worker, so the material/mesh boundary works. Work counts are unchanged: door 107 constructed /11 retained /231 atlas sources; movement 90 constructed /118 retained /198 atlas sources. Object scans remain small (door1.649 ms, movement1.892 ms), so a new object work queue would not address the regression.

The door still spends **30.582 ms** preparing actors and **46.034 ms** in object dispatch, including 25.407 ms early atlas source preparation. Actor siblings are: layers6.352, source7.367, graph2.010, shadow2.199, atlas source9.391, conditions0.087 ms; the remainder is actor traversal and call overhead. Source7.367 includes readiness3.462, optical0.079, realization0.578 and binding2.374 ms. These nested source values must not be added again to the actor total.

## Passive worker lead is also later

Door worker+sort excluding atlas grows **131.031→157.374 ms**. Movement grows **79.713→112.116 ms**. Environment-resource tasks account for 8.175/6.755 ms. Descriptor/source construction grows7.603→17.564 ms door and5.386→11.863 ms movement. Door actor metadata stays61.387→61.936 ms. Thus native work has less animation lead available even before allowance competition. Passive source/geometry constants should belong to admitted immutable source owners; only actual changed placement/membership needs operation derivation. No client should invent future undisclosed state: source constants can be prepared before input, operation-specific static packets only after receipt and before their authored cue.

## Actual last source paths

Door Head9 Idle depth: queue412.376 ms after click, dispatch wait102.755, intra-batch wait24.160, decode/upload13.727, publication wait19.150 ms. Publication is572.168 ms, gate releases573.507 ms. In the prior route the same depth had96.937 ms dispatch wait and7.079 ms publication wait; it was queued40 ms earlier. Additional door media delay is not a slower PNG decoder.

Movement Head15 Run depth dispatch wait improves27.522→1.220 ms; decode remains13.471→13.550 ms. The last support path then spends20.814 ms waiting for publication. Movement media actually improves; its regression is preparation completion timing.

Fireball also regresses: the second shot waits for native support while Head9 Die paths, already queued at1036 ms, wait675–729 ms to dispatch and39–54 ms to publish. Native cue/source priority must share the exact authored future requirement clock; a generic background lane does not guarantee its deadline.

## Three classes to remove from the critical serial path

1. **Independent source publication competing with mandatory native construction.** Separate completed-handle accounting from optional selection/dispatch work under the existing physical owner; prioritize exact next cue operands and use known animation lead. Keep finite backpressure and all CPU/fixture roles. Do not introduce an unbounded completed-image queue.
2. **Per-entry native material/source/atlas initialization on the scene lane.** Produce final source/output packets once on the existing finite worker from admitted immutable source descriptions and strong media refs, so main work is node/receiver identity attachment. Remaining transforms, actual sampling time and publication order stay on main. Moving only half the constructor leaves dozens of milliseconds serialized through two-millisecond slices.
3. **Repeated passive source/actor/world reconstruction after receipt.** Keep source constants under native source ownership; derive only dirty placement/support/membership against the proven base, start from already received event data early, then recapture current mutable actor ownership only at promotion. The present 157/112 ms worker lead cannot be called negligible or added to scene elapsed.


## Implemented correction, qualification still pending

The final-render-packet continuation of the existing completion plan governs
this correction. Completed texture receipt now calls `MediaWarmup.poll_sources`,
which retains physical publication/role/cancellation/dispatch ownership but does
not enumerate optional families. The optional lane alone performs that existing
maintenance. Receipt retains the established eight-images-per-frame limit and
actual shared 2 ms allowance. The focused real-owner checks pass 32 assertions,
including original pixels, exact GPU handles, CPU/fixture gates, independent
consumer cancellation, finite decode progress and an untouched optional-family
cursor during receipt. This is functional evidence, not another latency claim.

The second correction has the existing authored environment descriptor produce
private static source/receiver/output operands directly. The scene owner adopts
Node IDs and resources instead of rereading a newly constructed source's uniforms
and crop to reconstruct the same operands. Worker resources stay private;
existing layout/support/order and publication ownership remain. Native exact-pixel
qualification and a complete live route must precede acceptance.

Targets remain under 50 ms for both client readiness holds, with under 100 ms
the minimum, and no regression in the later Fireballs or approved graphics.
Server response, first animation, total playback holds, CPU work and publication
frame time remain separately reported. No result above meets the full target.

## Combined ownership route, 20:03:18 UTC — still not accepted

Actual GUI route `20261016T200318.764194Z`, 81 checks pass. Complete source:
`reveal-ownership-combined-live-analysis.json`; phase/source accounting:
`reveal-ownership-combined-decomposition.json`. Original profile:
`generated/profiles/2026-10-16T22-03-47-gallery-live-spells.json`.

| Client path | Media hold | World hold | Total hold | Packet to first animation | Largest playback frame |
|---|---:|---:|---:|---:|---:|
| Door | 27.273 | 394.430 | 421.703 | 103.058 | 33.644 |
| Movement | 109.345 | 0 | 109.345 | 152.918 | 31.505 |
| Haste | 0 | 29.617 | 29.617 | 68.924 | 28.126 |
| Fireball 1 | 17.565 | 15.707 | 33.272 | 68.669 | 34.841 |
| Fireball 2 | 0 | 31.584 | 31.584 | 68.858 | 35.480 |

All values are milliseconds. Idle same-view median/p95 is 9.870/15.070 ms.
There is no claim that a 422 ms door meets either the 50 ms target or 100 ms
minimum. The two Fireball maxima are also higher than the committed checkpoint;
they remain regression controls. Native tests prove equal pixels, not equal
performance. The route reports 106 ObjectDB instances and one resource still
in use at exit; aggregate counts do not identify their classes or a cycle.

Door construction charges 104.800 ms world work and 30.098 ms source receipt
over 65 frames. Actor worker derivation is now 3.353 ms after thin clip admission.
The actual native actor work is 30.179 ms: atlas source 10.556, layer 5.642,
source 5.938 (including readiness 1.960, bind 2.766, realization 0.634), graph
3.099, shadow 2.537 and conditions 0.170 ms. These nested leaves are not added
to their parent. Object dispatch is 28.309 ms: construction/adoption 18.130,
atlas source 6.588, source readiness 2.132 and scan 1.459 ms. Atlas capture
charges 12.923 ms over seven frames and binding 10.567 over six. The planner
worker occupies about 59 ms after scene capture. The environment resource task
costs 23.134 ms and completes about 552 ms after click; worker timings overlap
scene work and cannot be added to the hold total.

Movement world work is prepared before its cue. The actual last late sheet is
the controlled sorcerer's Head22 Run normal: queued 156.535 ms after click,
32.223 ms dispatch wait, 21.121 ms intra-batch wait, 14.161 ms decode/upload and
3.649 ms until the end of its publication frame. Another 18.643 ms media-labelled
interval has no missing source and records the admitted-world handoff; it is
not classified as a PNG load. Available movement was absent from body-action
recipe hints because it is defined in movement contexts; that ownership seam is
now corrected through the existing authored movement closure and condition pose.

Next coherent deletion: create genuinely new actor source/quad/receiving/output
Resources on the existing preparation owner, before selected PNG residency;
only missing texture uniforms finalize at readiness. Main keeps Node, graph,
shadow/support and actual UV/condition publication. Retained layers keep their
existing binding-only path. The remaining atlas-after-scene dependency is real
and reviewed, but no unimplemented overlap is counted as a saving.

## Ownership route controls, 20:17 and 20:27 UTC — door still fails

Actual routes `20261016T201709.646694Z` and `20261016T202703.496599Z`
each pass 81 functional checks. The latter source is
`reveal-media-owner-live-analysis.json` and
`reveal-media-owner-decomposition.json`; original profile:
`generated/profiles/2026-10-16T22-27-34-gallery-live-spells.json`.

| Path | 20:17 hold | 20:27 hold | 20:27 packet to animation | 20:27 largest playback frame |
|---|---:|---:|---:|---:|
| Door | 387.431 | 427.927 | 105.643 | 39.932 |
| Movement | 14.637 | 16.316 | 85.175 | 30.632 |
| Haste | 15.621 | 16.639 | 46.761 | 24.260 |
| Fireball 1 | 37.096 | 30.495 | 79.909 | 32.412 |
| Fireball 2 | 57.299 | 40.734 | 81.032 | 46.210 |

All values are milliseconds. Movement meets the readiness target in these two
routes; the door does not meet either threshold. Idle median/p95 is
16.354/22.800 and 15.676/19.558 ms respectively. Native pixel qualifications
cannot qualify these frame regressions.

The actor private Resource boundary reduces actual door actor scene work from
30.179 ms at 20:03 to 12.037 and 14.781 ms. Optional-source bookkeeping now
produces one selection job instead of 62 in the real 1,024-source constrained
owner fixture, with identical selected sources/budgets/roles/queue order.
Source receipt drops from 54.855 to 13.125 ms between the last two runs. None
of these improvements removes the whole door wait: the latter run charges
99.645 ms world work over 60 construction frames.

In that run object dispatch is 39.227 ms (construction/adoption 19.286, early
atlas source 6.498, repeated source checks 8.248, scan remainder 5.195).
There are 831 unsuccessful source checks even though one environment producer
already owns that closure. Separately instrumented actual Node create,
configure, attach and register cost approximately 0.251/1.718/0.379/1.141 ms
in the previous route; the 18–19 ms inclusive bucket must not be attributed
to Node allocation or used to justify a Node-pool rewrite.

The environment resource task completes 561 ms after click. Capture then
charges 14.701 ms across six frames (636–669 ms after click), the atlas worker
runs at 675–742 ms, binding charges 10.132 ms over five frames (752–783 ms),
and sampling completes around 790 ms. These are serial dependencies, not
independent worker CPU totals that can be added. Earlier trace images spend
222–240 ms awaiting dispatch although their actual PNG work is around 1 ms.

For texture reuse, the latter profile identifies 90 distinct environment paths:
15 have a publication before the door click and 75 afterward; every one has
exactly one publication in the captured route. These are colour/normal/depth/
mask source paths, not 90 props or evidence of duplicate physical texture
creation. The earlier full-lane capture separately counted 1,833 texture
creations for 1,833 unique paths. Each object still needs its own mutable
placement/visibility/material/receiving state; source reuse must not reconstruct
the same immutable asset facts for each of those occurrences.

Next changes are governed by the plan's dependency-chain amendment: same
16-image capacity in eight two-image required jobs, independent resident-row
environment batches on one task, worker-final private atlas directories and
output regions, and early input capture with exact canonical ordering. No
upcoming result is represented as measured improvement here.

## Requested tested checkpoint, 21:24 UTC

The complete handoff, failed approaches, phase breakdowns, raw evidence paths
and next owner boundaries are in
[CLIENT_PREPARATION_PERFORMANCE_HANDOFF_2026-10-16.md](CLIENT_PREPARATION_PERFORMANCE_HANDOFF_2026-10-16.md).
The final numerical data is committed separately in
[client_preparation_checkpoint_2026-10-16.json](data/client_preparation_checkpoint_2026-10-16.json).

Final real route `20261016T212402.703340Z`: 81 checks pass. Door hold is
310.550 ms (14.664 media, 295.886 world); movement 19.828 ms;
Haste 17.047; Fireballs 53.740/36.895. Packet-to-animation is
107.095/115.328/43.958/82.887/74.795 ms respectively. Post-onset maxima are
37.939/52.273/30.223/28.867/29.320 ms; before-onset movement and Fireball
also hit55.414 and46.126 ms. Idle median/p95 is13.025/18.669 ms.
The50 ms door target,100 ms minimum and100FPS/no-spike goals remain unmet.

Interleaved construction completes actual independent work earlier, and the
final actor shader-owner merge correction removes47 full receiving copies
(material sync7.035→2.796 ms), confirmed in the live scene. Main reveal
preparation still totals90.696 ms. The movement52.273 ms frame includes
12.883 ms modular shadows, with10.753 ms in its light-plane update bundle,
and8.572 ms atlas publication. The Fireball46.126 ms pre-onset interval
includes27.327 ms actual draw sorting. These remaining costs and unattributed
outside-Player intervals are explicit; this checkpoint is not performance
acceptance. Server Fireball execution remains separately561.969/446.251 ms.

Final-code native Studio passes8,686 checks without errors/warnings; actor
305 headless/341 native and12 exact pairs pass. The current physical media,
selection, streaming, shared account and actual-recorded world-preview checks
pass their assertions. Selection retains an80-instance shutdown warning;
the live route retains a missing caster portrait and130 ObjectDB instances/
one Resource at exit. Tests/import qualification do not hide those limits.
The user requested stopping here with the handoff and commit, rather than
another unbounded optimization cycle. No backend, graphics or artwork edits.
