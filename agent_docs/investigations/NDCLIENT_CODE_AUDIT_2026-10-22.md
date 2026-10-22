# Client recovery: code and execution audit, 22 October 2026

Evidence is source code, retained native runs and raw measurements. Existing completion narratives are not treated as proof. The initial investigation below used schema 16 with producer `9f81d5267`. The requested backend rebind uses `ad5a3220c7` / schema 18. The final section records the subsequent same-producer before/after recovery measurements; historical findings below retain their original scope.

## What the recovery actually fixed, and why the game is still slow

The recovery removed expensive work in specific stages. It did not restore every Opus optimization, remove the remaining stages, or explain the worst frames. These are separate findings:

1. **The opening environment barrier improved materially.** The adopted traces have environment commit work around 29–34 ms, compared with 629–857 ms in the older regressed traces. The former opening metadata barrier is no longer entirely before animation: `Session` can hand off compiled operations and opening sources before full metadata continuation finishes. The older source/workload differs, so these ranges are evidence of changed behavior, not a controlled speedup ratio.
2. **Tiny perception changes still trigger full-population work.** Opus `9b73f29a`, `sdk/audience.gd::_update_cells`, retained ordered columns and used binary insertion/removal for small deltas. Current `sdk/audience.gd::_update_cells` reuses the topology only when no cells change. Any addition/removal copies membership, sorts the full visible population through `Cells.sorted_points`, rebuilds its mask and realigns/re-encodes both light and hazard columns. An actual measured Move contains changes of +1/−2 and +3/−4 against approximately 1,250 visible cells. The compact wire representation does not require a full comparator sort for those changes. This is a concrete incomplete restoration. The saved timing does not isolate its exact cost.
3. **Publication still contains significant synchronous work.** The three Door runs include approximately 26–29 ms frames in which Play itself accounts for 25–27 ms. Lighting publication/table work contributes materially: one frame has 11.54 ms lighting, including 8.61 ms table work. These nested timings must not be added together. This path remains expensive, although its presence alone does not establish which part was introduced by the recovery.
4. **Some later Door pauses wait for physical character textures.** Raw media-gate traces show world, metadata and native readiness true while Head/Legs/Melee/Shield Idle sources remain missing. Missing paths fall from 23 to 3 to 0 before publication. These are not the former environment metadata barrier. Door has 32.5–43.1 ms media hold and 41.6–48.3 ms world hold; the latter includes readiness/publication delay, not just the roughly8 ms world derivation. Move has neither hold in these runs.
5. **The worst frames remain unattributed.** At the three maximum frames, total intervals are 43.940, 34.812 and 35.569 ms; measured Play CPU is 7.015, 6.919 and 5.163 ms. After separately measured diagnostics/HUD work, approximately 36.6, 27.5 and 30.1 ms remains outside those timings. Post-draw observations place much of that gap before the next Play work. GPU counters are delayed and viewport-scoped. The data does not justify calling this either a renderer stall or a test-harness stall. One peak coincides with private native warmup completion; the other two do not. Profile export/screenshots occur after sampling, and the explicitly measured validation scans occur after the peaks. Those are not explanations for these peaks.

The actual onset ranges are:

| Stage | Door | Move |
| --- | ---: | ---: |
| JSON decode | 4.84–8.22 ms | 2.55–3.02 ms |
| Canonical preparation | 25.79–30.06 ms | 29.12–29.48 ms |
| Presentation compilation | 7.38–8.30 ms | 8.23–8.52 ms |
| Opening metadata | 3.06–3.28 ms | 5.36–5.55 ms |
| Opening ready to first animation | 10.67–12.41 ms | 14.26–19.16 ms |
| Packet admission to first animation | 54.47–58.95 ms | 60.34–64.55 ms |
| User submission to first animation | 106–112 ms | 122–126 ms |

These rows describe overlapping/inclusive intervals, not an additive budget. Submission also includes work before the packet arrives. Canonical world fold is 15.69–17.23 ms for Door and 10.52–11.03 ms for Move; fact handling is 3.34–3.68 and 11.46–12.12 ms respectively. Full Door metadata continues for 100.6–105 ms while playback is already running.

Evidence: `.runtime/player-runs/20261022T104952.090707Z`, `20261022T105023.502631Z`, `20261022T105054.715949Z`; `.runtime/client-owned-closure-20261022/adopted-retime/measurements.json`; `generated/profiles/2026-10-22T12-50-15-gallery-live-spells.json`, `12-50-46`, `12-51-17`. Source was `2a094492` with installed factory `runtime-dragon-receiver-20261022-53075ee7ed11481f`.

## Ordinary startup was a separate, real failure

The normal `loading.gd` path starts a threaded load of `play.tscn`. Transitive static initialization in `presentation/lighting.gd` and `lighting_2d.gd` called `Catalog.environment_lighting()`. That reached `source_metadata.gd`, whose WorkerThreadPool branch creates another Thread and waits for it. The child then loads a script-backed metadata resource. This introduces a nested cross-thread script/resource initialization dependency during the threaded scene load.

Observed: the ordinary launch remained on “Loading the encounter”; directly loading `play.tscn` reached playable state. Replacing those five static metadata calls with a declared passive `lighting.res` dependency made the ordinary threaded launch reach playable state. Exact native-lock ownership was not stack-sampled, so the lock mechanism remains inferred; the failing path and successful intervention were executed.

The existing startup test preloaded `play.tscn` and therefore bypassed this path. It now enters through `loading.tscn`. Lighting checks 249 total and the corrected native startup check 7 passed. That functional startup took 3,344 ms with another game running; it is not a quiet performance benchmark.

Do not move that preload into `source_catalog.gd`: the environment builder reaches Catalog before writing `lighting.res`, creating a build dependency inversion. The runtime Lighting scripts are outside that builder dependency path.

## Studio: remaining concrete work and limits of the evidence

The 64-key measured preview consists of 36 standalone area samples and 28 composed windup/flight samples. Fresh 2479.001 ms and reset 2088.833 ms measure this demand after the reference world is prepared. Recording indexing 442.032 ms is separate. Zoom 174.283 ms requests 52 keys after residency and is not an equivalent cold comparison.

`studio/thumbnail_cache.gd` now reuses the composed pane and advances later or equal cuts. However:

- Queue order in `studio/timeline_view.gd` remains row, sample, then four quarters. Overlapping cast/flight rows move the composed clock backwards at their row boundary and force a fresh recording restore.
- `ReplayPanes.prepare` resets focus to the reference on every job; the thumbnail path then changes it again to the source.
- A ready composed sample still passes through separate polls for focus/return, arming post-draw/return, and verification/readback. The measured loop polls at most once per frame. Composed jobs are serialized through one pane; ordinary source work can batch up to 8.
- Composed requests bypass the ordinary disk-cache lookup. Optional prewarming skips them and cannot solve queued foreground demand.

These are identifiable repeated operations and synchronization points. No saved stage durations divide the full 2.48 seconds between restoration, preparation, camera work and readback. A generic new cache is not justified by these measurements.

There is also a separate accumulation risk in `presentation/native_source_startup.gd`: `_complete_request` scans the historically accumulated plan, deriving source identities again. Recovery commit `312ebe38` moved that call before the shared-budget and once-per-frame guards. A caller with no local eligible work can therefore consume the shared preparation allowance scanning historical work. Opus had the guards first. Current Gallery last-scan observations reach 406–465 microseconds with 26 keys and 572 retained material variants. The current eight-case Studio sequence reached at most 13 keys/159 microseconds; it does not qualify the older longer sequence that timed out after cases 63, 75, 78 and 82.

The old timeout captures are mixed: two have construction waiting at actor cursor 0, while one has no pending world and 35 missing images. Shared preparation budgets are exhausted in all three. This supports an accumulation/budget investigation, not a claim that one scan explains every 90-second timeout. Preserved evidence is under `.runtime/main-queue-20261022/finite-native-exact-point/`; current scan observations are under `.runtime/closing-repairs/accumulated-studio-cost-20261022/`.

## Actual missing work, including the new backend

| Area | Code-derived state and required work |
| --- | --- |
| Backend adoption | Rebound to frozen `ad5a3220c7` / schema 18, including current protocol, launcher/test/record defaults and regenerated content snapshot. Old schema16 recordings select their exact archived contracts; current live admission remains strict. |
| Dynamic audience/input | Implemented occurrence-level AudienceFact ordering, UUID member-mask remapping, private inventory/HUD revocation and human/Codex input boundaries. Fresh native summon and caster-defeat originals pass Python canonical and client compiler/timeline parity. No client HP-based dismissal or invented summon seats. Native rendering of every summon action remains separate qualification. |
| Ice removal | Current backend emits the original object contact with disintegrated destruction at actual removal. Qualify the client with fresh producer recordings instead of reconstructing the missing fact client-side. |
| Earth landing | Current backend has authored `action.earth_myrmidon.landing`; the client already binds the Earth rig's `AttackHeavy`. Fresh producer qualification is needed, not another landing provider. |
| Arcane Sword | Backend has independent `spatial_effect.spell.arcane_sword` identity, anchor/elevation and concentration-slot association. Client actor condition disables package lifecycle and lacks the independent spatial registration/render owner. This is real missing client work. |
| Partial Stone Wall remainder | Installed wall source observes only a current anchor equal to the birth anchor; both phases require that anchor. Retain original construction while applying current surviving sections. No new backend field is established as necessary. |
| Weapon contact on objects | `presentation/components.gd` explicitly reports `weapon_impact_object_contact_not_bound`. Impact placement has creature-rig handling, not the needed object-contact binding. |
| Animated destruction motif | Static image rows carry source_image_id; animation banks do not. Wall residue join resolves static wall images, without animated frame/fragment mapping. |
| Summon presentation | Elemental, myrmidon and dragon body assignments exist. Dragon still lacks authentic per-pose mouth/optical placement, breath release/contact/VFX and supported aerial contexts. Cambion/Deva/Djinni use substitute selections. Body assignment is not full action qualification. |
| Immutable presentation histories | Implementation exists, including tests that source retirement cannot mutate captured pixels. Equipment transitions/live cost remain unqualified; recorded Magic Missile owner removal/recast is absent from the retained test originals. Do not call the whole history mechanism unimplemented or add a second one. |
| Original case qualification | Shove/fall and ordinary stabilization positives exist. Ranged Shield positive remains missing. VoluntaryDropProne/Intimidating recording setup/discovery problems are not sufficient evidence that their renderer is absent. |
| Audio | Spell release/concentration bindings are explicitly disabled; torch extinguish references a missing cue. Prone application/removal already bind fall/rise sounds. The goblin contact mapping has Rolling/direct_arc but no Run/CrouchWalk. The cue manifest's eight missing-family labels are not eight wholly absent behavior categories. Source inspection cannot establish perceptual mix quality or replace listening/art review. |

The initial manifest snapshot had 575 rows: 431 runnable/eligible, 59 excluded executable, 59 retired, 25 helpers and 1 other. Eligible does not mean passed. The library snapshot had 416 cases, 398 recorded and 18 failed; a recording count is not a feature-completion count. Do not reuse earlier broad action/alternative totals as fresh verified inventory.

## Scope of the immediate repairs

The startup fix and an in-process Restart game button are bounded usability repairs requested during this investigation. Restart retains the Godot process, Play scene, renderer and loaded assets; only the encounter Session/Timeline and backend native world are replaced. The first exit/relaunch implementation was incorrect and has been removed. Backend 18 adoption and the subsequently authorized performance patches are recorded separately below. Performance targets remain open.

Final live validation: **88 checks passed, no failures or script/engine errors**, 16.3 seconds. Two actual menu restarts after movement retained the process, scene, camera, HUD, viewport and all 85 initially displayed native textures. Each restored the backend starting position and command counter, retained the old journal, and accepted subsequent movement. A third accepted reset deliberately received an actual bootstrap 404; the client remained open and its retry attached to the same accepted epoch instead of resetting it again. Receipt: `.runtime/tests/20261022T114657.148715Z/summary.json`. Reproduce with `python3 tools/run_tests.py --only player_restart_checks --jobs 1`.

The separate real HTTP/native-worker test passed in 4.095 seconds: changed turn/command state, duplicate reset yielding 200 + 409, same listener and native worker, preserved prior spool files, one retained active game reservation, and zero owned workers after shutdown. Its temporary recording was removed by the test; no durable receipt is claimed. Reproduce from the client root:

```sh
env PYTHONPATH="$PWD/tools:/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267:/home/tommaso/.cache/ndclient/dnd_engine-9f81d5267/sdk/python/src" NDCLIENT_HOST_RESTART_TEST=1 /home/tommaso/.cache/dnd-engine/venv/bin/python -m unittest discover -s tests -p test_launcher_restart.py -v
```

Tests used isolated owned runs. They did not interact with the user's running game. Existing windows do not acquire changed scripts or launcher capabilities automatically; the fix is available through the updated launcher on the next normal launch.

Remaining attribution needed before asserting that performance is solved: a controlled comparison of the small-delta sensory path, same-frame ownership of the large unmeasured frame gaps, staged composed-preview timings, and the actual accumulated Studio sequence. These are specifically missing measurements, not reasons to conceal the proven source regressions or to claim that the present targets have been reached.

## Executed backend rebind

The active producer is a Linux-native frozen copy of backend `feature/rules-checking` commit `ad5a3220c7f05e8ec08778f5487bce6e167db051`, with protocol 1 / player schema 18. The client schema and identity match that producer. `play.cmd` and active tooling use the same copy; the launcher refuses inconsistent parent Python imports before creating a game. The regenerated content inventory changes producer metadata and removes Summon Dragon's obsolete damage/resistance choices; no content IDs were added or removed.

The SDK folds audience membership before the same occurrence's world and nested perception rows, then admits its body rows. It remaps all four member masks by observer UUID and removes revoked private inventory/HUD sheets. Recorded event deltas publish those after-values at their actual cuts; existing compiler owners receive the updated audience. Input still requires live attachment and acknowledged/displayed catch-up for both human and Codex boundaries. Older original journals remain unchanged and use only explicitly archived contracts.

Studio's library now accepts those same explicit archived contracts for playback, while their producer/output evidence stays historical. Without this change, its old current-wire-only eligibility check marked every existing library original stale after the rebind. It loads the two small archive identities once per library build, not once per case. Historical semantic test harnesses likewise select their original contract; current producer JSON and trusted-operation checks use fresh schema18 originals.

Fresh inputs are retained under `tests/fixtures/schema18/`: Fire Bolt (9 original packets per seat), 32 reference fold vectors, human/Codex summon control (56 packets and full per-record Python states), and caster defeat (56 packets and full per-record Python states). The latter records the backend's existing regression unchanged: one caster's weapon departs with `caster_defeated` while the other caster's weapon survives. These prove native-worker publications; they are not claims of HTTP capture or GPU output.

Executed checks, all with zero failures or script/engine errors:

| Duty | Result | Receipt under `.runtime/tests/` |
| --- | ---: | --- |
| Current protocol + preserved protocol oracle | 73 + 8,865 | `20261022T120136.561413Z` |
| 12 affected SDK, session and archived replay suites | All passed | `20261022T120517.960359Z` |
| New-backend ordinary startup and in-process restart | 7 + 88 | `20261022T120808.030338Z` |
| Original human/Codex audience, input, full canonical and production compiler/timeline checks | 1,076 | `20261022T121503.337820Z` |
| Schema18 reference fold vectors | 1,253 | `20261022T121503.337820Z` |
| Caster-defeat full canonical fold and production recording/compiler/timeline | 56 + 7 | `20261022T121621.752583Z` |
| Presentation requirements, two-seat replay comparison and current trusted operations | 630 + 2,351 + 184 | `20261022T121824.814242Z` |
| Studio library, including archived playback and historical evidence separation | 85 | `20261022T122224.148295Z` |
| Seven affected producer/historical semantic harnesses | 6,477 | `20261022T122136.324573Z` |

Across the latest result for each affected suite: 31 suites, 23,730 checks, zero failures. The first new-test run failed on a missed `ROOT`→`fixture_root` reference in the parameterized fixture harness (`20261022T121033.426490Z`). The first Studio library run failed because its older originals had become unavailable (`20261022T121824.814242Z`). Both failures were corrected before their passing runs above; these receipts remain retained. The retained originals do not claim arbitrary observer permutations or exact same-occurrence grant/body coverage. No test interacted with the user's open game; it keeps its existing producer until the next normal launch. Backend adoption does not establish performance recovery, fresh Ice/Earth rendering qualification, or completion of the remaining presentation inventory.


## Executed recovery and recorded-path repair on schema 18

The authorized narrow changes are now implemented. Small visibility deltas retain ordered points with binary insertion/removal; bulk changes keep the existing full-sort path. Membership forks, masks, light/hazard alignment and immutable prior states remain. This avoids full comparator sorting, not all population-sized work. The three current live originals contain two bulk opening discoveries followed by small movement cuts; initial Door discovery is not an incremental case.

Visible composed thumbnail jobs for the same actual recording/generation now run by exact time, view and original order, preserving ordinary priority slots and the obsolete tail. A reused composed pane retains focus until its actual focus changes. Framing arms the existing post-draw fence in the same poll; the subsequent source/camera/context-signature checks remain. No new cache or relaxed draw requirement was introduced. Native startup completion now checks the shared allowance and existing frame markers before scanning accumulated history. Registration, lease withdrawal, local readiness and failure ownership remain in place. This prevents redundant scans; it does not bound one scan's cost or identify the old 90-second stall cause.

All measurements below use backend `ad5a3220c7`, schema 18, the same installed Factory package `runtime-dragon-receiver-20261022-53075ee7ed11481f`, native Vulkan/Forward+. Live runs use1600×960, camera size12 and the same existing Gallery UI route; the preview control renders640×480 full-context panes. Three live runs per side were serialized, followed by the same four-view preview control. No caches were flushed. These are observed before/after cohorts, not randomized runs with controlled whole-desktop contention. The historical schema16 numbers earlier in this document are not the baseline for this comparison.

| Measurement | Before | After |
| --- | ---: | ---: |
| Door submission → first native animation, range | 112.605–119.515 ms | 103.463–110.006 ms |
| Door submission → first native animation, median | 115.883 ms | 108.987 ms |
| Door completed SSE admission → first native animation, median | 49.075 ms | 49.763 ms |
| Move submission → first native animation, range | 125.163–139.992 ms | 118.425–121.680 ms |
| Move submission → first native animation, median | 126.797 ms | 121.230 ms |
| Haste potion submission → first native animation, median | 87.993 ms | 97.187 ms |
| First Fireball submission → first native animation, median | 95.859 ms | 116.069 ms |
| Second Fireball submission → first native animation, median | 116.591 ms | 114.438 ms |
| Move canonical consumer, median | 29.666 ms | 23.907 ms |
| Move journal reduction, median | 28.154 ms | 22.351 ms |
| Move command's maximum frame interval, range | 21.486–22.929 ms | 17.164–19.236 ms |
| Haste-potion command's maximum frame interval, range | 14.934–18.883 ms | 18.195–43.029 ms |
| Whole ready-session maximum frame intervals, range | 32.848–35.495 ms | 34.472–43.029 ms |
| Fresh four-view preview, 64 samples | 2547.043 ms | 2399.360 ms |
| Reset/reload four-view preview, 64 samples | 2023.096 ms | 1897.205 ms |
| Changed-zoom preview, 52 samples | 173.861 ms | 181.154 ms |

The cohorts show mixed results: Door and Move submission medians fell, while the Haste-potion and first-Fireball medians rose. Door's completed-admission-to-animation median increased slightly despite its lower submission latency. The second Fireball's median fell, but its observed range widened from 112.901–120.392 to 108.420–140.180 ms. The largest after-cohort frame interval occurred during the Haste-potion command. These three-run cohorts establish neither a broad latency improvement nor the cause of each change; the full comparison is retained in `.runtime/performance-recovery-20261022/comparison.json`.

First animation is the existing post-draw observation of a visible actor's non-Idle native clip and UV, not a separately measured pixel transition. Submission excludes the Fireball UI's deliberate aiming dwell. Canonical/Journal/phase figures are nested inclusive measurements, not additive budgets. Preview indexing remains separate (485.113/487.132 ms before/after). Both fresh/reset previews still miss 200 ms, and whole-session frame maxima did not improve. Performance recovery remains incomplete.

Actual workload verification: all six live runs finished 83 checks with no failures or script/engine errors, completed Door, viewport Move, potion use and two Fireballs selected through the native GUI, drained to the canonical SDK state and cold-replayed their original journals. Each retained populated terrain/objects and committed movement facts. All six end-of-run native PNGs were manually inspected and show the full encounter, actors and HUD. This is evidence of a real gameplay workload, not proof of every intermediate frame or every effect's artwork.

The user's blank screenshot file timestamp falls in the third baseline's shutdown interval: the full encounter PNG was saved at 13:23:02.492 UTC, the report at 13:23:02.652, the clipboard file at 13:23:03.525 and the launcher exited at 13:23:04.534. This is consistent with the test's blank teardown draw; file timestamps alone cannot prove when every screenshot was captured or explain every reported artifact. The test now identifies itself in its window title and draws the existing closing notice before native retirement, after profile sampling and saved evidence. Gameplay/runtime timing is not shortened by this test-only change.

Receipts are under `.runtime/performance-recovery-20261022/{before,after}/`: exact invocation/result summaries, source diffs, `live-metrics.json`, retained preview reports and live logs linking the raw journals/profiles/images. New live runs are `20261022T133847.919930Z`, `20261022T133918.711543Z`, `20261022T133949.359134Z`. The micro comparison on 57 actual recorded topology cuts, including all three current baseline journals, passed 1,130 checks and reduced the aggregate median fork/update/mask CPU time from 213.252 to 58.628 ms. That batch figure is not per-frame latency or FPS. Its receipt is `visible-current-133025/micro.json`.

Affected qualification:

- Eight SDK/headless suites passed in `.runtime/tests/20261022T132924.086357Z`; current-journal extension passed separately as above.
- Source-cut reuse (630), startup lifecycle failure (4) and native thumbnail queue (45) passed in `.runtime/tests/20261022T133646.656302Z`.
- Startup scope (212) passed in `.runtime/tests/20261022T133759.319777Z`. The first added test failed because one process-frame signal did not necessarily advance the engine counter from its deferred starting context. It now waits for the real counter change; runtime assertions were not weakened. The initial failed receipt remains retained.
- Native preview resource/cold-versus-retained context comparison passed 352 checks in both measured cohorts, including its exact image, seek and camera controls.
- The actual eight-case Studio sequence passed 10,981 checks in 96.5 seconds, all eight originals passing through one reused Studio, seeks, both audience journals, playback and loops. Receipt: `.runtime/tests/20261022T134054.128101Z`; preserved detailed report: `after/studio-eight-cases.json`. This bounded sequence does not qualify the historical 63/82-case accumulated stalls.

The visual repair is the shared recorded-path guard in `presentation/baked_effect.gd`: write the current transform into the adjacent interpolation column before the existing texture upload, without advancing committed history or adding an upload. The installed client reproduced 28 GPU transform failures across four actual Fireball/Scorching source placements before the change; the final run passed all 246 checks with zero failures. Current fractional frames, held draws, jumps/seeks, private owners, shader bindings and retirement are exercised. Final cleanup has no script/engine errors or object leaks; three driver/resource warnings remain recorded. Receipts: `.runtime/recorded-path-frontier/{before.json,after-cleanup.json,after-cleanup.log}`. This qualifies the current interpolation frontier, not every spell's art or exact arbitrary same-handle historical reconstruction. Ordinary replay epoch changes retire/recreate native handles. Factory's broader recorded audit is separate evidence, not a substitute for these client runs.

Next unresolved measurements remain full-context preview stage costs and same-frame attribution of the largest frame intervals; the longer accumulated Studio history also remains unqualified. The bulk visibility/world publication and physical character-source waits remain outside the small-delta repair. No new backend field, generic manager/cache, shortened draw fence or expanded feature queue is justified by these results. Changes remain uncommitted.


## Follow-on speed batch and bounded attribution

Packed light/hazard columns now use exact native byte-array edits for small
visible-cell changes, retaining the linear fallback for large changes and short
inputs. There is no new cache or canonical owner. Eight affected SDK suites
passed10,139 checks in `.runtime/tests/20261022T140030.209906Z`; the saved-original
extension passed5,124. In each of three current six-sensory-cut journals, median
column processing was2.212–2.239ms before and1.053–1.062ms after, including decode
and encode. This is a six-cut column contribution, not a per-command latency
saving. Exact evidence: `.runtime/performance-recovery-20261022/value-delta-current/`.

The optional native test probes retain actual gameplay, full recorded context,
existing budgets and all draw fences. They add no production telemetry or image
readbacks. Current-source preview probes passed352 checks; live probes passed83.
The first live probe localized a74.857ms interval to61.405ms between pre/post-draw
callbacks and12.443ms current Play work. The extended probe's largest60.244ms
interval contained52.045ms after the observed late pre-draw marker; a different
36.783ms Door interval contained35.153ms current Play work. The late marker is
missing from Godot's in-signal connection snapshot, so callback order was not
validated. These findings do not establish pure GPU or exclusive upload cost.
Artifacts are under `probes/` and `draw-tail/`; upload-transition frames were
observed, but no causal upload attribution was established for the largest gap.

The preview's existing frame rings show repeated optional preparation even at a
paused cut. Opus has the same repeated optional calls. Its ready result does not
prove all optional blood/audio/native/history obligations complete; no speculative
completed-owner guard was added. Opus likewise has the current rotation waits.

The bounded quarter change compares existing canonical ordered visible-point
arrays instead of rebuilding point strings on every style check and deactivation.
The geometry lookup and exact changed-visibility/scenery/wall checks remain;
receiver readiness and native mask/publication fences are unchanged. This is a
new narrow improvement, not a recovered Opus hunk. Quarter progress12, native
rotation108, wall lifecycle11, and full-context thumbnail352 checks pass. In the
single instrumented before/after preview runs, availability worsened:
2282→2910ms fresh and1780→2686ms reset. Rotation preparation CPU totals were
61.7→65.4ms fresh and64.4→63.7ms reset. Therefore this run establishes no preview
latency improvement; targets remain unmet. Evidence: `preview-phases/` and
`quarter-after/`. Changes remain uncommitted.

## Human targeting follow-up, after this speed batch

The human reported Fireball aiming constrained toward characters instead of any
server-allowed floor location, target clicks also reaching the tile behind,
awkward body/ground selection and dot selector, manual confirmation after a full
multi-target selection, and door highlighting including its arch. Requested
behavior: all server-allowed positions receive real previews; one gesture has one
target; body and ground choices are both accessible with an explicit ground
override where ambiguous; completed multi-target selection can auto-confirm with
a settings toggle; opening a door highlights the door alone. The human is
checking server publication separately. This is the next authorized client
batch; do not invent backend eligibility or contact another chat.


## Targeting implementation and current backend fix

The native picker now resolves selected actions through the admitted binding and
falls through decorative artwork to the actual floor ray. Body artwork remains
selectable; a floor contact resolves to an entity only when the current response
offers one unambiguous subject there. Hold **V** to aim by the floor ray. In mixed
body/position continuations, explicit body identity wins ordinarily and the floor
continuation wins with V. One left press is consumed; release cannot append another
target. This qualifies event routing, not proof of the original reported double
click's cause. Source comparison found one world-click call and an immediate
selected-target return in both current and Opus code.

The selected ground cell now has a stronger perimeter and subtle fill, preserving
actual AoE fill. Door highlighting excludes native frame role2 and keeps leaf
roles1/3. Settings can disable automatic completion. With the default enabled,
only the accepted current selected Preview can finish a multi-target/free-aim
selection, and only when it is confirmable with no remaining target or position
continuation. Initial/hover/undo replies do not auto-submit; old actor, authority,
revision, generation, row and prefix replies remain refused. Upcasts rely on server
continuations because discovery can retain the base projectile count.

Actual server queries exposed a separate Fireball defect: in frozen `ad5a3220c7`,
requests for[9,7] and[9,6] returned the same[9,7] geometry/footprint. The worker
consumes the first extra coordinate into a synthetic target; all such targets
share an index, and the Preview cache key omitted the coordinate. The failed
raw request/response originals remain in `.runtime/targeting-preview-68b11239/`.
The backend checkout already contained committed fix
`bedc3d92dc14c3e5a53e452b4c2efad80e4fccf1`, which includes each target position in
that key. No backend implementation was changed here. The client launch and
recording defaults now use its committed archive at
`/home/tommaso/.cache/ndclient/dnd_engine-bedc3d92dc`; server IDs were regenerated.
Schema18, protocol identity and content identities are unchanged by this fix.
No other chat was read or messaged.

The current server probe in `.runtime/targeting-preview-2c3ec544/checks.json`
passes24 checks: moving the footprint, a genuine visible/unoccupied[8,5] floor
aim, equivalent indexed/free-aim positions, repeated A/B/A targeting and undo,
and a level2 Magic Missile that retains a base count of3 but offers continuation
after3 picks and completes after4. All original HTTP pairs are retained. No
commands, state revision changes or new gameplay packets occur in this probe.

Native pointer/settings controls pass30/51 checks. The current-data controller
suite passes80 checks and folds the genuine SDK journal, checks delayed/reordered hover replies,
empty-floor previews, repeated recipients, manual/automatic confirmation and
upcast completion. Results are retained in
`.runtime/targeting-usability-20261022/final-selection-summary.json`.
The obsolete harness first failed on missing adapter methods and then on comparing
indexed picks with free-aim receipts and integer cast levels with JSON floats;
it now uses exact recorded receipts for each route and SDK wire-value equality.
No runtime admission or stale-reply guard was weakened.

The native current-backend Gallery route passed81 checks with no script/engine
errors, including action-family/level selection and two Fireballs through actual
UI input. Its journal, client traces and full-scene PNG are retained at
`.runtime/player-runs/20261022T144534.101177Z/` (final confirmation semantics).
The PNG was visually inspected and
shows populated terrain, actors and HUD. This qualifies the targeted gameplay
route; it does not establish a new performance improvement.

Additional bounded quarter CPU evidence: on1251 cells from an actual current
journal,256 style comparisons took176.894→14.737ms median for the same mask,
188.382→21.367ms for a value-equal copy, and202.406→21.758ms for a changed final
coordinate. All29 controls passed. This is a repeated-call microbenchmark, not
preview availability or FPS; the full preview timing regression above remains.
Receipt: `.runtime/performance-recovery-20261022/quarter-style-micro.json`.
Performance targets and the long accumulated Studio workload remain open.


## Commit cleanup qualification, 22 October 2026

The source and original regression fixtures are being saved in four focused
commits: schema18/backend and incremental sensory folding; shared Studio/startup
preparation; recorded-trail interpolation; in-place restart and targeting.
Generated test reports are preserved separately under
`.runtime/commit-cleanup-20261022/`; they are not source changes.

The full fast run completed205 suites:202 passed initially and3 exposed stale
test obligations. All3 corrections passed focused reruns: unique floor object
selection now retains typed binding and still refuses two-object ambiguity;
the AudienceFact expectation extends the frozen pre-audience state-only oracle;
the live follower prefix test now uses genuine current schema18 originals rather
than archived schema16 live bytes. Runtime admission was not relaxed. Combined
qualification and individual original failures are retained in
`.runtime/commit-cleanup-20261022/fast-qualification.json`.

Final-source Studio qualification now covers the eight archived-original cases
again:10,972 checks, zero failures,97.4 seconds. Targeting also passed80 checks
from its durable `tests/fixtures/schema18/targeting-preview/` original fixture.
Receipt: `.runtime/tests/20261022T145858.501460Z/summary.json`. The Studio exit still
reports one ObjectDB instance leak warning, also present in the preceding
10,981-check run; no new script/engine errors were reported. This small shutdown
warning remains uninvestigated and is not a new performance diagnosis.

The local Library index contains416 historical case entries:398 recorder-success
flags and18 retained failed recordings. These counts are not398 current-backend
qualifications or approved artworks. Old failed attempts can coexist with newer
successful shove/stabilization originals; they remain evidence. Ranged Shield
still lacks its required successful ranged-reaction original. Library replay
still depends on the retained/regenerated `.runtime/studio-library/index.json`
and original journals; cleanup preserves that directory.

Studio is functionally qualified on the bounded final sequence and affected
preview controls. Its latest instrumented64-image four-view preview remains
2.910s fresh /2.686s reset, zoom247ms, versus200ms. The long63/82-case accumulated
stall remains unqualified. No performance recovery completion or broad art
approval is claimed by these commits.
