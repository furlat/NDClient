# Client preparation and frame-spike handoff — 16 October 2026

## Purpose, scope and acceptance

This is the handoff for the user-requested checkpoint, including unsuccessful
attempts. A faster individual function or a passing pixel comparison does not
establish an improved player-visible wait. The separate accounting ledger is
[REVEAL_LATENCY_DECOMPOSITION_2026-10-16.md](REVEAL_LATENCY_DECOMPOSITION_2026-10-16.md).
The controlling design is
[THREE_OPERATION_CLIENT_COMPLETION_PLAN_2026-10-16.md](THREE_OPERATION_CLIENT_COMPLETION_PLAN_2026-10-16.md).
The committed [compact timing data](data/client_preparation_checkpoint_2026-10-16.json)
preserves the checkpoint's per-action parsing, reduction, compilation, source,
world, server and frame counters without requiring the large ignored profiles.

The user asked for both door and movement client readiness holds below 50 ms,
with below 100 ms the minimum; preserve the approved graphics, authoritative
event order and the later Fireball paths. The user subsequently requested a
decent tested stopping point, a complete breakdown and reasoning, then a commit.
That checkpoint request does not mean the performance targets have been met.

Client: `C:/Users/tommaso/Documents/Dev/NDClientGodot`, branch
`codex/godot-native-lighting`. Previous committed checkpoint: `461bd07`;
earlier baseline: `9c0340a`. The commit containing this document is the new
checkpoint. Native Godot 4.7.2, Windows Forward+/Vulkan, RTX 5090. The live route
uses a 1600×960 view, camera size 18, VSync disabled, no FPS cap. The Windows
client lives on Windows; WSL launches it and runs the Python backend. Backend
root: `/mnt/c/Users/tommaso/Documents/Dev/dnd_engine`.

No backend, Factory, accepted shader/art, lighting calibration/cap, wall modes
or visual treatment redesign belongs to this work. Original assets remain
ignored and in their original location. New native source metadata and optical
facts are metadata, not altered artwork. Runtime schema/hash/freshness validation
is not a solution to this task; tests/import qualification own that work.

## What each number means

1. **Server dispatch** is the engine/host-recorded request execution boundary.
   `server_exchange_ms` also contains host exchange work. The difference is not
   automatically network latency or engine CPU. Nested server hooks were off in
   the latest route, so deeper attribution requires the server's own capture.
2. **Packet-to-first-animation** measures client work after the received record
   boundary. Framing, parse, reduction, compilation, source preparation and
   first displayed animation have distinct stamps in the analysis.
3. **Media/world holds** are elapsed timeline wait intervals during the whole
   action. A door can start animating promptly and then pause at its reveal.
   The media label can include an admitted-world handoff with no missing PNG;
   inspect the recorded gate and missing paths before calling it loading.
4. **Preparation account** is actual elapsed scene-thread work charged to the
   shared 2 ms host allowance. Indivisible overruns remain charged. Worker CPU
   intervals overlap it and one another; do not add those to wall holds.
5. **Publication/playback frame** is an actual process-callback interval. Its
   CPU parents have nested children. GPU/render timestamps can lag a frame;
   they are not extra CPU children. High average FPS does not excuse this spike.

The crucial bound: 102 ms of main-thread preparation requires roughly 51
2 ms slices. At an 8 ms frame interval, that alone spans about 408 ms before
accounting for useful animation lead. Moving counters between phases cannot
make that work fit a 50 ms hold. Work must be deleted, completed on its correct
private owner, or genuinely overlapped before the authored boundary.

Earlier preparation work is also relevant. The 15 October sequence in the prior
plan measured Fireball **prepared-to-animation** 421.37→143.74→72.40 ms, later
53.23/54.84 ms. These omit the frontend and are not comparable to complete
packet-to-animation numbers. The next plan records a warm opening tail split
into 13.606, 15.647 and 23.514 ms process intervals plus 4.228 ms until observation.
Optical reuse, incremental role publication and completing ready handoffs in the
same frame addressed that path; later source/room changes still introduced
other holds. The older arithmetic is retained in the linked plans, not relabelled
as a current-code result. Native spell/blood/attachment source admission is
already part of that earlier checkpoint; no accepted VFX is redesigned here.

## Live route and history of measured outcomes

Every row below is the same kind of actual player journey: open the Gallery
door, enter the large room, drink Haste, select/click two Fireballs. These are
not replay-only samples. Each listed completed route passed 81 functional
checks; those checks do not assert the performance target. Single runs are
not statistical confidence intervals. Work counts/appearance and environment
load must be checked before attributing every timing difference to an edit.

All numbers below are milliseconds. Fireball columns are total media+world
holds, not authored projectile travel or total spell duration.

| Run UTC | Door hold | Movement hold | Fireball 1 / 2 holds | Idle median / p95 | Interpretation |
|---|---:|---:|---:|---:|---|
| 15:44:06 | 943.054 | 304.363 | 26.381 / 22.932 | 11.324 / 15.470 | Earlier baseline |
| 16:54:08 | 705.609 | 400.445 | 84.067 / 39.945 | 9.696 / 15.360 | `461bd07`; door better, movement/Fireball holds regress |
| 19:02:18 | 433.611 | 73.203 | 16.085 / 0 | 9.722 / 14.173 | Baked fixture optics; door still fails |
| 19:16:24 | 664.338 | 286.393 | 48.655 / 170.681 | 15.654 / 20.502 | Optional receipt competition regression |
| 19:36:53 | 529.048 | 1341.598 | 29.772 / 38.034 | 13.655 / 19.973 | Serious movement regression; not accepted |
| 20:03:18 | 421.703 | 109.345 | 33.272 / 31.584 | 9.870 / 15.070 | Thin metadata/catalog/static batch combined |
| 20:17:09 | 387.431 | 14.637 | 37.096 / 57.299 | 16.354 / 22.800 | Actor resource packet + movement hints; movement target met only |
| 20:27:03 | 427.927 | 16.316 | 30.495 / 40.734 | 15.676 / 19.558 | Optional-source churn/front-queue fixes; door not improved |
| 20:58:20 | 437.177 | 121.052 | 48.996 / 42.728 | 17.247 / 22.611 | First early-atlas/batching route; still fails, movement regresses |
| 21:16:51 | 324.479 | 0 | 16.842 / 43.973 | 14.201 / 18.250 | Interleaved construction/private capture; door still fails; before final shader-owner correction |
| 21:24:02 | 310.550 | 19.828 | 53.740 / 36.895 | 13.025 / 18.669 | Final code; owner-stamp correction; door and frame targets remain unmet |

Exact run directories are `.runtime/player-runs/YYYYMMDDTHHMMSS.fractionZ/`.
The principal directories, respectively, are `20261016T154406.286364Z`,
`20261016T165408.501605Z`, `20261016T190218.815139Z`,
`20261016T191624.664159Z`, `20261016T193653.230794Z`,
`20261016T200318.764194Z`, `20261016T201709.646694Z`,
`20261016T202703.496599Z`, `20261016T205820.243947Z`, and
`20261016T211651.809081Z`; final code: `20261016T212402.703340Z`.

The 20:58 loaded client predates the constructor-target-count correction saved
at 20:58:47 UTC. It also predates the final construction interleaving and private
source-capture completion. Do not attribute those later changes to this row.

## Full decomposition of the 20:58 door, before the final batch

Readiness hold: **437.177 = 46.231 media + 390.946 world**. First animation
after packet: 92.601. Largest reveal/playback frame: 45.780. These are distinct
measurements, not additive stages of one clock.

The media intervals are 11.888 ms with admitted-world handoff and no missing
path, then 34.343 ms including actual missing Head9 Idle colour/support/normal
operands. The latter paths were queued about 479 ms after click, waited about
146 ms for dispatch, 4.9–16.0 ms within their batch, 5.2–16.6 ms decoding/uploading,
then 17.1–20.1 ms to the end of their publication frame. Do not call the whole
interval slow PNG decoding.

Reveal main-thread preparation is **102.138 ms**; the command-wide 102.403 ms
also includes 0.265 ms in an earlier opening owner. Disjoint reveal parents:

| Work | ms | Meaning |
|---|---:|---|
| Actor preparation | 16.128 | Graph 4.900; layer 5.239; resource capture 1.354; shadow 2.391; conditions .219; source .372; dispatch/remainder 1.653 |
| Object preparation | 31.885 | Constructor/adoption 22.839; atlas priming 7.451; source checks .369; scan 1.226 |
| Atlas preparation | 32.403 | Source setup/capture 19.964; incident base capture 3.830; bind 6.095; reserve 2.506; wait polling .008 |
| Environment source capture | 3.174 | Capture private strong-resource inputs |
| Other step-body work | 16.746 | Ground/light/cookie/membership/scenery/order/sampling/control; existing profile cannot honestly assign all remainder to individual functions |
| Outside step-body timer | 1.802 | Top-level owner refresh/poll/caller work |

Actor source optical .143 ms is inside actor source .372 ms. The object leaves
sum exactly to 31.885 ms. Never add them to that parent again.

The eligible environment Node create/configure/attach/register leaves sum to
4.848 ms, including only .461 ms of actual Node allocation. There are 96 worker
rows and 11 ordinary rows among 107 constructed objects. Those 11 excluded
fixture rows create 33 primed sources. Therefore **22.839−4.848 is not an
18 ms Node-allocation cost**: it includes packet adoption and the ordinary
fixture constructor path. Additional recording-only leaves now distinguish
worker Nodes, visibility, atlas adoption/queue, and ordinary constructors.

Actual causal timeline after click:

- Passive room result is admitted around 470.8 ms.
- Environment resource batches begin completing around 488 ms; final batch is
  complete around 650 ms.
- Actor resource work does not start until the actor lane around 571 ms.
- Eligible object Node adoption happens only around 720–818 ms, because the
  old actor-first dispatch keeps succeeding before the object fallback runs.
- Atlas input closure is only around 861 ms; planning starts around 883 ms,
  ends around 971 ms, then native finalization/sampling completes.

Early capture alone therefore overlapped some order work, but left the earlier
light→actor→object constructor dependency intact. This is why the local CPU
improvements did not produce the requested total improvement.

## Publication frame and steady-frame spikes

Original profile: `generated/profiles/2026-10-16T22-59-04-gallery-live-spells.json`,
frame **26113**. Interval 45.780 ms, Player callback 43.660 ms. Disjoint parents:

| Player phase | ms |
|---|---:|
| Native lighting | 19.440 |
| Session/timeline | 5.247 |
| World publication | 4.809 |
| Draw/order/output | 3.953 |
| Optional preparation | 3.704 |
| Actor sampling | 2.738 |
| Wall visibility | 1.505 |
| Actor membership | 1.131 |
| Other measured work/remainder | 1.133 |

Outside Player is 2.120 ms, including diagnostics .197 and HUD .134; the rest
includes other callback/render work. GPU/native-render counters are not added
to the CPU account.

Native lighting 19.440 = atlas 15.071 + shadows 3.945 + projection .416 + .008.
Atlas 15.071 = reconcile 7.291 + material sync 6.063 + projection 1.398 + style
.083 + .236 remainder. Reconcile 7.291 = spec/setup .481 + reservations .006 +
receiver publication 5.355 + output 1.365 + addresses .020 + prepared release
.008 + .056 remainder. Receiver publication contains registry 2.437 and binding
2.916; binding already contains bulk 2.913. Output contains adopt .604,
transport .583, records .132 and .046 remainder.

The publication reports **zero address-index updates and zero address uploads**;
884 preserved rows is a count, not a repeated address repair walk. Prior worker
times (79.514 planning, 42.582 group work, 18.841 receiver records, 6.025 outputs)
are historical worker children carried into the result, not more CPU spent in
this publication frame.

Concrete remaining anomalies and costs:

- The first actor sample has 54 source changes, all UV-only, but atlas sync
  makes 47 full receiving-material copies (61 frame-only copies in the frame). The
  failed source-owner/version interval needs exact attribution; UV-only count
  alone does not prove which predicate failed. This is part of final packet
  qualification, not permission to suppress genuine condition/source changes.
- Native registry publication still installs 279 source records and updates
  support ownership. Those writes are ownership handoff, not texture loading or
  backend validation.
- Reconcile output revisits 279 prepared outputs; output sync separately
  checks their owner/material relationships and actual priority/wall fields.
  Actual current painter priority and wall masks remain scene-owned.
- Shadow update has no new Nodes/casters, but costs 3.945 ms. Internal children:
  update 1.731, layout .816, snapshots .597, sources .567, bind .073, retire
  .028, internal remainder .093, wrapper .040. Cookie measurements are children
  of sources, not additional costs. It reports 47 full caster copies vs seven
  frame copies.
- Optional preparation still spends 3.704 ms on this publication frame.
- Idle median/p95 17.247/22.611 ms is below the desired 100+ FPS. No claim that
  readiness fixes also solve steady rendering or every frame spike.

## Fireballs, movement and server separation in that route

| Action | Server dispatch | Server exchange | Client packet→animation | Client media+world hold | Largest playback frame |
|---|---:|---:|---:|---:|---:|
| Door | 83.891 | 126.637 | 92.601 | 437.177 | 45.780 |
| Move | 70.392 | 77.032 | 133.148 | 121.052 | 36.014 |
| Haste | 16.989 | 22.235 | 63.608 | 23.085 | 25.065 |
| Fireball 1 | 663.990 | 672.258 | 73.427 | 48.996 | 29.727 |
| Fireball 2 | 460.581 | 467.116 | 96.042 | 42.728 | 37.959 |

Server outer phases: door execute 69.444/audience projection 14.172; movement
58.312/11.858; Fireball 1 645.718/18.019; Fireball 2 439.725/20.586 ms.
The two Fireball server executions are suspiciously long and belong in the
server worker's investigation. No server edits were made here. That does not
excuse the independent client holds and frame spikes above.

Door JSON parse/guard is 19.307 ms (Variant 16.417, lexical guard 2.878), text
decode .554, schema .208, presentation compilation 20.068, required media worker
116.184. Movement parse 10.953, compile 17.388, required media 35.185. Fireballs
parse 5.930/4.141, compile 9.788/7.658, required media 26.942/30.625. These are
nested worker/client measurements, not terms to add to readiness holds.

## Texture reuse: what is actually shared

Identical physical source paths share the physical texture owner. An earlier
captured full lane creates 1,833 textures for 1,833 unique paths; it does not
show a separate texture for each knight or each instance. Actor/item UUID,
transform, tint and HP are not physical source identities.

In the 20:27 room trace, 90 distinct selected environment paths appear: 15 have
a publication before the door click and 75 afterward. Every one is published
once in that recording. These paths include colour, normal, depth and masks;
they are not 90 props. Physical reuse does not automatically reuse private
placement/material/visibility/atlas state. Do not treat an environment requirement
count as a texture allocation count, or assume other-view paths are unused
without comparing the exact current-quarter construction closure.

## Changes tried, measured deletions and tradeoffs

| Change | Actual deletion or outcome | Limitation / failed inference |
|---|---|---|
| Exact current-quarter construction media gate | No all-four-view barrier for ordinary live cuts; initial/replay/rotation remain exhaustive | Filenames alone cannot identify unused views across differently oriented instances |
| Baked fixture optical facts | Exact native binary facts for 16 torch frames; removes roughly35–36 ms CPU optical reduction per decoded frame | `.tres` float roundoff failed exact qualification; `.res` preserves values; new frames retain old worker fallback |
| Thin body native metadata | Category summaries + lazy selected clip; actual actor derivation47.977→3.353 ms, where44.068 ms had been four category ResourceLoader calls | Cold native load elapsed was not proven disk-only; not a total door speedup |
| Shared catalog/table records | Frozen four-operation probe goes from8 table reads to2 then0/0/0; actual immutable owner retained across workers/revisions | No global registry or UUID-based source duplication; no hash/freshness scans |
| Environment final resource packet | Private materials/mesh/source operands made off-thread; actual source rederivation231→33 door and198→30 move in earlier route | Explicit fixture/water exclusions left ordinary constructors; main identity/adoption work remains |
| Static canvas batch | Private final static RID draws under one hidden parent; source directory transfers once per source | Keep full bind order metadata; an attempted dynamic-only bind-id list failed24 real invariants and was corrected |
| Actor resource packet | Main actor work30.179→12.037/14.781 ms in earlier controls; actual UV/condition and late-noise cases qualified | Does not itself remove source queues or the whole door hold |
| Movement choice hint | Offered movement uses authored movement/condition clips instead of absent body-action recipe | Actual movement holds109.345→14.637/16.316, but subsequent route regressed121.052; not permanently solved |
| Source receipt separated from optional planning | Completed-handle receipt no longer enumerates optional-library families; actual source receipt54.855→13.125 ms in controls | Whole-world main work stayed99.645 ms; receipt alone did not solve door |
| Optional selection revision ownership | Real1,024-source constrained fixture:62 selection jobs→1, identical selections/bytes/roles/queue,32 idle frames launch none | Functional/count evidence, not a measured10× action improvement |
| Pending-front selection | Removes per-image full pending-queue scan; uses stable bounded priority/cancellation | Same source roles and pins still required |
| Required producer granularity |8×2 images rather than4×4; same16-image private bound, optional-only4 single-image jobs; up to16 pointer receipts | Real shared/publication2 ms checks unchanged; constants are not speedup evidence |
| Resident environment batching | Same one task processes resident rows; each result joins before row transfer | Resource batching alone did not overlap actual object Nodes while actor-first dispatcher still monopolized them |
| Future urgency | Current/onset stays strict first; future actor/environment operands then share urgency | Deletes artificial future-actor-publication→room-priority fence; no predicted state or weakened media gates |
| Early atlas capture/seal | Same real IDs/candidate, canonical source/row/group sequence; actual native59-pair oracle exact | Initial run left constructor ordering intact, so planner still started883 ms after click |
| Constructor target-count fix | Canonical full membership expansion no longer reopens already completed changed-source lanes | Saved after20:58 client loaded; not measured by that route |
| Final construction/private-capture batch | Starts resource producers before unrelated light phases, interleaves existing construction lanes; finishes private source capture/style once | Final qualification and live measurements are recorded in the checkpoint result section |

Rejected or removed approaches: raising the 2 ms allowance; dropping source
roles or unseen-view state improperly; fake speculative events; a new queue or
renderer; Node pooling based on an inclusive constructor bucket; recursive
runtime validators/freezing; duplicate source discovery; per-object full visibility
scans; a constructor wait-suppression cache whose deadline/count wakeups could
deadlock. The latter cache was removed before qualification; the existing bounded
cursor scan costs about1.226 ms over the whole operation and did not justify
another wakeup dependency.

## Final construction batch: what actually improved at 21:16

The 21:16 route passes 81 functional checks and reduces the total door hold
437.177→324.479 ms. That is a useful 25.8% single-run reduction, **not 10× and
not acceptance**. Movement has no observed media/world hold, but packet-to-first
movement animation is still 86.398 ms and its publication frame is 39.593 ms.
Zero readiness hold is not zero input delay or a smooth frame guarantee.

Actual door main preparation is **92.007 ms**, down from 102.138. The command's
95.037 ms includes 3.030 ms in the earlier opening owner. Disjoint reveal work:

| Work | ms | Nested leaves, already included |
|---|---:|---|
| Actor preparation | 13.458 | Graph 3.564; layer 5.059; capture 1.165; shadow 2.480; conditions .145; source .369; remainder .676 |
| Object preparation | 30.847 | Constructor/adoption 21.092; atlas priming 8.209; source checks .357; scan 1.189 |
| Atlas preparation | 24.546 | Sources 13.627; incident capture 3.671; bind 5.662; reserve 1.586 |
| Environment source capture | 2.113 | Captured strong-resource operands |
| Other step-body work | 19.679 | Control/cookie/light/ground/membership/scenery/order/sampling; not individually timed leaves |
| Outside step-body timer | 1.364 | Caller/poll/owner overhead |

The 21.092 ms constructor/adoption contains ordinary excluded constructors
12.658, worker Nodes 4.697, worker visibility .444, worker atlas adoption 1.836,
worker queue .971 and .486 remainder. There are still 107 constructed objects,
96 worker rows, 11 ordinary rows and 33 primed sources. Allocating Nodes is a
minor leaf, not a justification for a new object pool.

The actual dependencies now overlap: passive result at 451.369 ms after click;
actor resource capture observed at 473.420; atlas source lane at 487.242;
first joined environment batch at 535.269; first actual environment Node
adoption at 550.347 versus 719.774 previously. Construction completes around
745.852; canonical capture 761.066; planner wait/start observed at 776.493
versus 883.268. Planner join/bind is at 852.718 with 71.681 ms worker elapsed;
sampling ready at 874.690; publication at 914.979. The world cue hold is still
614.492→927.528 ms. Phase-end samples are not exact internal call timestamps.
For example, `membership_begin` frames include atlas work; their 9.519 ms is
not a 9.519 ms membership-constructor measurement.

The remaining global capture/seal and 92 ms actual main work explain why the
total still fails. Early capture alone was insufficient; construction dispatch
had to change too. It was wrong to treat the faster isolated constructor or
planner overlap as proof of a solved door. The history above keeps those failed
inferences and regressions visible.

This route's door publication is 40.289 ms, Player 39.058, native lighting
18.651 = atlas 14.764 + shadows 3.579 + projection .300 + .008. Receiver
publication improves 5.355→4.469 and output 1.365→1.219 ms, but material sync
regresses 6.063→7.035 ms with the **same 47 full dynamic / 61 frame-only copies**.
Movement's 13.528 ms atlas includes receiver publication 8.512: registry .715,
bindings 7.795. Bulk group work 7.197 includes register .417 and transfer/cull
.790, leaving 5.990 ms unassigned ordered replacement/loop/reporting work.
There are 26 replacement bindings versus three at the door; the replace branch
does not increment its ordered-bind timer, so zero there is not proof of free
replacement. Both publication frames report zero address-index updates/uploads;
1,253 preserved movement rows are not a repeated address walk.

### Ownership failure caught by final qualification

A new strict first-publication assertion failed six actor cases: each had three
full dynamic receiving copies and zero static/output copies. Diagnostic owner
comparisons found the exact failed predicate: `group.source_shader` stayed null;
all material, shader-target, binding, version and change-base relationships were
otherwise correct. `private_actor_binding` merged completed metadata into
`new_group` with Dictionary's default `overwrite=false`, keeping its initial
null shader. The correction is `merge(..., true)` for the completed metadata.
It changes no texture, shader or authored value. The original assertion remains.

After that correction, actor checks pass **305 headless / 341 native**, including
12 byte-exact received/final framebuffer pairs, zero full receiving copies on
first publication and subsequent Hidden+UV changes, late texture/noise fills and
cancellation. Logs: `.runtime/checkpoint-actor-owner-fixed-{headless,native}.log`.
The 21:16 live route predates this correction. The final route confirms the
actual 47-copy anomaly is gone: 47→0 full dynamic copies, 61→108 frame-only
copies, material synchronization 7.035→2.796 ms. Shadow copies have a separate
owner and are not automatically fixed by this actor metadata change.

## Qualification and raw evidence

Focused qualifications during the continuation, not all final-code runs:

- Environment source frozen parity:97,626 assertions; eight source framebuffer
  plus four received/final pairs across four views,800 exact received cells.
- Body metadata frozen facts70,213; actual six-record legacy body comparison
  14,419; source ownership203; actor material/geometry3,726; overlap16.
- Static ownership/native suites: staged2,618 with59 exact pairs; WorldAtlas172
  with10 pairs; receiver ownership562. These include initial/retained/sparse
  floor/sight, current hover and canonical seal after backwards source arrival.
- Actor private resources after the final metadata correction:341 native checks
  with12 exact assembled/received pairs against the frozen constructor;
  305 headless checks. Environment focused headless:25,874 checks.
- Physical media streaming50, shared residency44, priority34, optional selection12, environment
  row streaming35, shared preparation admission35. CPU-image/fixture promotion,
  same textures, pins, cancellation and the real2 ms allowance are assertions.
- The full native Studio before the final shader-owner correction passes8,847
  assertions without errors/warnings. The final-code rerun is reported below.

The legacy `tests/media_role_race_checks.gd` still assumes the older single-owner
dictionary, removed selection-precomputation fields and four required workers.
A bounded attempted run exposed those stale fixture accesses and was stopped;
tentative test-only adaptations were reverted. It is not claimed green. Current
physical-owner suites above cover the changed source boundary. Do not turn
unsupported legacy implementation-field assertions into alleged pixel parity.

Native Godot can exit0 after a script error. Read the log for `SCRIPT ERROR`,
`ERROR:` and warnings, in addition to the report/exit code. Earlier full live runs
also report aggregate ObjectDB instances/one Resource retained at shutdown;
focused ownership suites pass, but aggregate counts do not identify a cycle.
Final-code results and any remaining shutdown warnings must be explicit below.

Local raw artifacts are intentionally under ignored `.runtime/` and
`generated/profiles/`; they are present in this workspace but not guaranteed in
a fresh clone. Important prefixes:

- `.runtime/reveal_wait_decomposition.{py,json}`: accounting for the committed baseline.
- `.runtime/reveal-ownership-combined-*`:20:03 route and decomposition.
- `.runtime/reveal-private-actors-*`:20:17 route and decomposition.
- `.runtime/reveal-media-owner-*`:20:27 route and decomposition.
- `.runtime/reveal-parallel-owners-*`:20:58 route and decomposition.
- `.runtime/reveal-final-packet-*`:21:16 route and decomposition.
- `.runtime/checkpoint-final-*`:final-code21:24 route, decomposition and Studio.
- `.runtime/antislop-parallel-owner-main-decomposition.json`: disjoint102.138 ms
  main preparation and phase/worker timing evidence.
- `.runtime/early-canonical-staged-native.log`,
  `.runtime/early-world-atlas-{headless,native}.log`,
  `.runtime/private-finalization-ownership-native-qualified.log`.

Each player-run directory contains actual journal/SSE records, Godot log, live
command reports and media-gate trace. The analysis names the original profile.
Do not overwrite an older result or quietly relabel it as a later-code run.

## Reproduce and resume

From `/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot`:

```bash
PYTHONPATH='/mnt/c/Users/tommaso/Documents/Dev/dnd_engine:/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/sdk/python/src' \
  /home/tommaso/.cache/dnd-engine/venv/bin/python tools/play.py \
  --scenario gallery_sorcerer --test-script res://tests/live_spell_checks.gd \
  --live-fireball-ui --profile-pipeline --profile-view-size 18

python3 tools/analyze_live_pipeline.py .runtime/player-runs/ACTUAL_RUN \
  --output .runtime/NEW-analysis.json
```

For native tests, use
`C:/Users/tommaso/Documents/Dev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`
with `--path C:/Users/tommaso/Documents/Dev/NDClientGodot`,
`--rendering-method forward_plus --rendering-driver vulkan` and
`--script res://tests/TEST.gd`. Headless omits renderer options and adds
`--headless`; a test awaiting `RenderingServer.frame_post_draw` needs native.

Run profiling and native tests serially. Freeze source before each live run;
edits saved after launch do not change that loaded Godot process. Avoid heavy
analysis concurrently with capture. Keep actual actions through the player
bar/target path; replay-only validation does not measure input/response behavior.
Close only the owned test/client processes. Closing `tools/play.py`'s client
ends its encounter/owned backend; never terminate unrelated Factory windows.

Resume from the final actual critical path below. Verify source identity/work
counts, ordinary gameplay versus Studio, both Fireballs, cancellation and exact
output. Do not restart approved lighting/art work, infer a GPU bottleneck from
the card model, or hide a failed total behind a smaller leaf.

## Checkpoint result

**Tested checkpoint, performance incomplete.** Final actual route
`20261016T212402.703340Z` passes81 functional checks. It uses the one-line actor
shader-owner correction as well as the coherent construction/private-packet
batch. No further production changes were made after that capture. Relative
to the committed16:54 checkpoint, door hold705.609→310.550 ms and movement
400.445→19.828 ms improve, but the door still fails both the50 ms target and
100 ms minimum. Steady100+ FPS and no-spike targets are also unmet. Do not
present this as the completed performance task or claim10× overall improvement.

### Final route: separate server, onset, holds and frames

| Action | Server dispatch / exchange | Packet→first animation | Media / world hold | Largest post-onset frame |
|---|---:|---:|---:|---:|
| Door | 77.776 / 95.961 | 107.095 | 14.664 / 295.886 | 37.939 |
| Movement | 72.211 / 78.956 | 115.328 | 0 / 19.828 | 52.273 |
| Haste | 16.996 / 18.563 | 43.958 | 17.047 / 0 | 30.223 |
| Fireball1 | 561.969 / 566.083 | 82.887 | 34.064 / 19.676 | 28.867 |
| Fireball2 | 446.251 / 449.037 | 74.795 | 13.776 / 23.119 | 29.320 |

All times are milliseconds. Final idle same-view225 frames: median13.025,
p9518.669, maximum21.894. Relative to21:16, door improves13.929 ms and the
second Fireball improves7.078 ms, but movement hold regresses0→19.828 and the
first Fireball16.842→53.740. These single-route differences are not a causal
benchmark of the final one-line fix. Copy counts establish its deletion;
variable totals and frame regressions remain reported.

Server outer phases, execute/audience: door65.822/11.691; movement59.579/12.335;
Haste15.451/1.378; Fireballs539.105/22.603 and429.452/16.585. Fireball execution
is still suspiciously long. No backend change was made here. The GUI Fireball
gesture deliberately sweeps several targets for one second before confirming;
its full gesture→animation clock is not pure confirmed-click response latency.
Packet timing and the explicit holds above exclude that intentional aiming.

Here is the complete opening path, followed by the main-thread/draw tail.
Each row's frontend columns sum to its frontend endpoint. The tail is elapsed
wall time after preparation, not another measurement of compilation.

| Action | Final framing | Decode/admit | Canonical consume | Setup | Compile | Opening media | Unassigned handoff | Frontend subtotal | Ready→animation tail | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Door | 1.188 | 23.651 | 24.051 | .005 | 15.114 | 3.566 | .127 | 67.702 | 39.393 | 107.095 |
| Movement | .476 | 11.263 | 18.063 | .006 | 15.709 | 6.295 | .094 | 51.906 | 63.422 | 115.328 |
| Haste | .049 | 1.218 | 2.738 | .009 | 6.808 | 6.922 | .093 | 17.837 | 26.121 | 43.958 |
| Fireball1 | .492 | 6.481 | 4.738 | .008 | 11.297 | 7.247 | .095 | 30.358 | 52.529 | 82.887 |
| Fireball2 | .200 | 4.149 | 6.403 | .006 | 7.025 | 6.615 | .093 | 24.491 | 50.304 | 74.795 |

Within decode/admit, JSON parse is21.511/10.562/.970/6.055/3.800 ms;
Variant parsing18.853/8.980/.846/5.374/3.332 is nested there, as is the existing
lexical guard2.646/1.572/.117/.672/.461. Text decode is1.349/.326/.017/.181/.118;
schema envelope.267/.193/.210/.188/.186. These children are not extra frontend
stages. Full future-media metadata85.300/38.338/16.027/31.575/30.291 has a
different scope from the opening-only media column and overlaps later playback.
The compact JSON preserves the actual reducer/compiler children and source
counts; no runtime schema or freshness scan was added in this continuation.

### Final door critical path

Main reveal preparation is **90.696 ms**; command-wide90.951 includes the earlier
opening.255. Disjoint owners: actors13.711 +objects29.044 +atlas24.109
+environment source capture3.989 +other preparation/wrapper19.843. Worker total
207.971 includes atlas69.977 and derive/sort137.994 historical parallel elapsed;
it is not added to either the main account or the295.886 ms world hold.

Object29.044 = constructor/adoption20.763 +atlas priming6.719 +source checks.394
+scan1.168. Constructor20.763 =ordinary12.349 +worker Nodes4.362
+visibility.448 +atlas adoption1.944 +queue1.115 +remainder.545. Atlas24.109
=sources13.113 +incident capture3.452 +bind5.872 +reserve1.672. The source gate
reports zero failed object source waits,107 constructed,96 worker rows and11
ordinary rows. Those11 actual fixture exclusions still matter. Fewer shared
PNG loads do not make their private constructor/adoption work disappear.

Observed frame-end timeline after click: future construction316.186; first
environment resource result355.295; actor resources408.746; construction complete
around599.703; membership objects624.316; scenery styles630.252; atlas wait
644.062–707.976; ready/sampling715.474; publication frame7833 at753.413.
The world gate spans469.497→765.383 ms and includes the37.939 ms publication
interval. During that gate35 complete frames charge60.406 ms world work and
75.517 ms total preparation, with only1.498 ms unused allowance. The hold is
not296 ms of an idle queue; substantial real work remains. The media-labelled
14.664 ms opening hold has admitted-world pending and no missing PNG paths.

### Remaining spikes, including those outside the reveal

| Frame / context | Interval / Player CPU | Measured cause and limit of attribution |
|---|---:|---|
| Door7833 publication | 37.939 | Full material copies now0; material sync2.796 ms. Main private completion and native publication remain. |
| Movement7933, before onset | 55.414 / 39.567 | Native lighting16.497 includes projection14.095; session16.595 includes preparation-step11.347; optional4.912. These are nested, not extra additive children. Outside Player15.847 ms remains unattributed. |
| Movement7962 publication | 52.273 / 44.195 | Lighting21.913 =atlas8.572 +shadows12.883 +projection.449 +.009. Session5.476; world5.431; draw3.921; optional2.876; actor1.593; remaining Player2.985. Outside Player8.078 ms unattributed. |
| Haste8077 | 30.223 / 8.013 | Outside Player22.210 ms is not accounted for by HUD.089 or the captured render clocks. Not established as GPU, server or PNG work. |
| Fireball1 frame8189, before onset | 46.126 / 37.019 | Draw ordering27.347 includes sorting27.327 ms. This is a targeting/pre-onset spike, not projectile rendering. Outside Player9.107 ms remains unattributed. |
| Fireball1 /2 post-onset maxima | 28.867 / 29.320 | Better than earlier large pauses, but still above the no-spike/100FPS objective. Per-frame nested CPU retained in the raw profiles and compact data. |

Movement's shadow wrapper12.883 contains sync12.836: update10.869 (light-plane
bundle10.753; casters.043; camera/output.058; target.003, remainder.012),
layout.532, snapshots.621, sources.455, bind.096, retire.042 and.221 internal
remainder. The light-plane bundle computes four projected corners and changes
plane geometry, material parameters and native light properties. The existing
timer does not isolate which native setter blocks; it is not evidence that
four vector operations consume10 ms. There are zero new actors/casters/meshes
and zero cookie reads in that frame. The native render/GPU counters use other
clocks and cannot be added to this CPU breakdown.

The unchanged-address optimization remains active: preserved rows are not
re-uploaded. The real remaining publication costs concern source/receiver
binding, output state, shadow plane updates and draw sorting. Disabling approved
lighting or deleting actual state changes is not an acceptable shortcut.

### Qualification, limitations and next owner boundaries

- Final native Studio: **8,686 checks, zero failures/errors/warnings**, real
  movement/OA, Hide/reveal/light, invisibility perspectives and lethal jump/OA
  recordings; seeking, backwards seek, looping, ordered prefixes and private
  audio ownership. A separate no-oracle movement playback window measures
  median6.962/p958.938/max22.011 ms. That small recorded fixture is not the
  large live Gallery or all spells. Functional capture/oracle windows are not
  performance samples. Log: `.runtime/checkpoint-final-studio-native.log`.
- Final focused actor tests305 headless/341 native,12 exact fixture pairs;
  environment25,874 headless. The source/receiving/output fixtures qualify
  the stated shared algorithms and actual late/UV/condition cases; they do not
  constitute visual approval of every asset or spell.
- Eight final focused suites pass their assertions: media streaming50, shared
  residency44, priority34, optional selection12, selected-action sources37,
  environment streaming35, shared admission35 and real-recorded world preview
  10,079. Selection's37 checks still emit an80-instance ObjectDB shutdown
  warning; do not call that suite clean shutdown. Other seven logs are clean.
- Final live log retains the missing `portrait:creature.generic_caster` warning,
  **130 ObjectDB instances leaked** and **one resource in use at exit**. There
  are no gameplay ScriptErrors, but this is not an error-free exit. Isolated
  cancellation/pixel tests do not prove the aggregate leak solved.
- Legacy media-role fixture migration remains open as described above. Assets,
  derived packages and raw profiles remain ignored; native metadata regeneration
  needs the existing local authoring package. Fresh-clone CI without that
  package is not claimed. No unrelated Factory process is closed.

Resume with three concrete boundaries, rather than another local setter chase:

1. Finish the remaining scene-thread constructor/atlas packet work as one owner
   change. Start from the actual90.696 ms disjoint account, including ordinary
   fixture constructors12.349, atlas24.109 and other19.843. Keep clocks/Nodes on
   their correct owner and preserve canonical seal/publication. Quantify what
   disappears and what remains; moving a timer cannot meet50 ms.
2. Complete changed-state native publication/sampling, using the real movement
   shadow light-plane10.753 ms and draw-sort27.327 ms reproductions. Separate
   scene calculations from indivisible native calls before assigning a cause;
   preserve exact depth, rank, material, shadow and lighting output.
3. Complete received-action opening/owner handoff. Final frontend totals are
   67.702/51.906/17.837/30.358/24.491, with39–63 ms additional scene/draw tails.
   Parsing/reduction/compilation and shared-account admission remain distinct.
   The server's long Fireball execution is a separate worker issue, not an
   explanation for those client tails or an authorization for backend edits.

Independent anti-slop, correctness and plan/anti-OOP reviews approve this
bounded ownership checkpoint. They do not approve unmet performance. All
owned live/native validation processes are closed at the checkpoint; no demo
is deliberately left open.
Finish-time process inspection found only separate VFXFactory Godot processes;
those were left alone. That inspection does not attribute unexplained frame
intervals to Factory or establish an isolated GPU benchmark.
