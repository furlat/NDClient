# NDClient refactor and recovery: post-mortem at cancellation

**Later human authorization,22October:** bring the two reviewed pending proposals
into the client, commit, retime and update this record. The cancellation account
below preserves its original stopping boundary. Only this bounded follow-through
is resumed; the broader queue and heartbeat remain stopped/paused. The completed
follow-through and retiming are appended below; no causal speed improvement is inferred from
adding scenarios and diagnostics.

22 October 2026. Written at the human's explicit instruction to give up the
ongoing work and document the failure. This is a stopped-state record, not a
plan or authorization to resume. No fixes, builds, captures or tests were
launched to write it. All artwork and audio remain unreviewed.

## Outcome and responsibility

I did not deliver the requested combination of completed integration, preserved
rendering and recovered responsiveness. I introduced avoidable repeated work,
let implementation accumulate ahead of an accepted runtime checkpoint, and
reported source repairs and focused passing examples too much like completion.
The human had to repeatedly identify the same mismatch and redirect the work.
That execution and reporting failure is mine.

The task was to move authoring into clean resources and shared systems while
preserving the Opus client's rendering, lighting, scheduling, clocks and speed.
The schema migration required real adaptations. It did not require per-event
whole-store scans, repeated global visibility construction, synchronous Library
rebuilding or restoring the same preview world repeatedly. Those costs were not
justified by the requested architecture.

Some source defects were repaired and some measured client intervals improved.
That does not establish a completed speed recovery, a clean whole-current
native/live checkpoint or a usable, accepted Studio. Conversely, it would be
inaccurate to claim that every change was ineffective or that all remaining
costs were newly introduced. The evidence below makes those distinctions.

The human described approximately twelve hours of work without the expected
result. I have not reconstructed a precise twelve-hour accounting and will not
invent one. The observable failure is that repeated work, reviews and passing
checks had not produced the requested accepted outcome when the work was ended.

## What went wrong in the code

The source baseline before the migration is `9b73f29a`, whose runtime equals its
parent `1c4b9eb6`. The first migration is `119ddede`. Attribution below comes
from the preserved source/history audit, not author names or an assumption that
all later defects came from one change.

| Change | Concrete failure | State at cancellation |
|---|---|---|
| `119ddede`: actor/item transition capture | Per-event collection-shell snapshots and full-store identity comparisons replaced incident mutation capture. Some capture work also ran when no recording was requested. | Writer-local capture and recording guards were restored in the recovery series. This source repair does not prove that the whole reducer is back to its earlier cost. |
| `119ddede`: sensory/disclosure migration | Retained sensory indexing was lost; entered-area disclosure walked retained object geometry and searched resent-ID arrays. Work grew with the retained world instead of affected rows. | Retained sensory work and the accepted-state support/suppression/connector index are restored; structural checkpoint `23e14a2e` contains the latter. Rollback, reinsertion order and current schema semantics were retained. |
| `291e092c`: residue/environment integration | Local changed-cell source discovery repeatedly constructed the entire visible-cell Dictionary, even for partial states without residues. The work landed inside the measured slow environment continuation. | Empty/local work and immutable-mask ownership were repaired. Historical long media holds and failed receipts remain evidence; their entire duration cannot be assigned to one expression. |
| `119ddede` and `291e092c`: Library/offline loading | Worker-backed, bounded Library publication became synchronous construction/rebuilding; more uncached metadata was read, and packet zero was parsed twice. | Existing worker/publication and packet-zero ownership were restored with the required protocol refusal. Passing Library controls do not measure every catalog/search workload. |
| `291e092c`: composed preview integration | Input-bearing thumbnails used complete recording restoration/world preparation for different samples, serially. This was substantial extra work compared with source-only thumbnails. | Identical-cut/view and forward-prefix/pane reuse were added, with resize and optical invalidation. Current cold/reset explicit four-view preview availability is still about2.82/2.25seconds, above200ms. |
| Expanded preparation consumers | Discovery and requirement construction could consume time before downstream consumers saw the updated allowance. Repeating an expensive prefix could leave little construction progress. | Prefix accounting and exact held-operand reuse were repaired. The old accumulated-process90s installation stalls remain unresolved. A separate process-global completion scan is a source-confirmed cost candidate, not a proven cause. |
| Selected/optional source work | A canceled offered-choice job could keep a serial body-path traversal occupied while selected work waited. The selected job itself was cheap. | Cancellation boundaries were repaired during recovery. The underlying serial/nonpreemptible traversal predates the migration; increased cold work enlarged its exposure. No complete per-millisecond causal allocation was demonstrated. |
| `ba5d0262` / `a33d1e59` and later actual-body integration | Actual-body histories can use several full-viewport colour/depth targets; predecessor realization also added work. | Incremental prefix ownership exists, but conditional continuous capture cost remains open. It is not an established explanation of the Gallery's largest frame spikes. |
| `24a993f0`: resource admission ownership repair | Removing a global cached-as-ready shortcut exposed repeated consumer admission/draw waits for physically resident resources. | The ownership repair was necessary; restoring the unsafe shortcut would be wrong. Exact completed PhaseResource sharing is implemented, broader completed-phase handoff remains incomplete. |

The detailed original code and introducing-history evidence are preserved in
[the Opus regression audit](OPUS_PERFORMANCE_REGRESSION_AUDIT_2026-10-21.md)
and [the earlier rendering post-mortem](CLIENT_RENDERING_REGRESSIONS_2026-10-21.md).
Their dated “current/open/unapplied” labels describe the21October boundary;
they must not be copied into a22October status without reconciliation.
The subsequent [recovery execution record](../OPUS_RECOVERY_IMPLEMENTATION_2026-10-22.md)
describes the implemented restorations and their bounded qualification.

There were also correctness failures in shared ownership and inspection:
weapon-material withdrawal, direct-effect versus causal-event IDs in Studio,
tile removal propagation, thumbnail effect-version identity, Follow coverage,
residue refresh and immediate-blast ground placement. Several were repaired in
the recovery series. A passing isolated effect had never established all those
lifecycles. Camera-strip and shadow-notification defects discovered during the
work included omissions already present in the Opus baseline; they were real
bugs, but assigning their introduction to this migration would be false.

## What the latest measurements establish

These are saved runs completed before cancellation, not new post-mortem tests.
Client `d6fffec81715a843ee13820adf0066748d96a3cd`, pinned engine
`9f81d52676d4cea78be0be951dfc51a756050032`/schema16, installed complete Factory
`runtime-dragon-receiver-20261022-53075ee7ed11481f`.

Three serialized ordinary native GUI Gallery routes used the same five commands,
1600×960 viewport and camera12 as the earlier83-check route. They each exited
naturally0, with83 checks/zero failures and no script/engine errors or owned
leftovers. Before/after native Godot process snapshots were empty; no external
preview was closed. No OS/driver cache was flushed. These observations are not
continuous whole-host contention monitoring or a single-change package A/B.

| Metric, ms | Run1 | Run2 | Run3 |
|---|---:|---:|---:|
| Door actual submit → first sampled animation |150.598|106.874|133.893|
| Move actual submit → first sampled animation |148.650|134.785|139.151|
| First Fireball actual submit → first sampled animation |121.753|97.656|110.382|
| Second Fireball actual submit → first sampled animation |126.436|126.513|123.232|
| Door client packet framing start → first sampled animation |65.168|53.388|59.473|
| Door canonical consumer, inclusive |28.726|25.864|26.743|
| Door presentation compilation |9.245|7.195|8.099|
| Door opening prepared → first sampled animation |17.950|12.051|15.173|
| Door backend dispatch, independent server clock |33.640|35.092|35.095|
| Initial ready observation |1256|1158|1256|
| Full after-initial-ready frame p50 |7.694|7.643|7.537|
| Full after-initial-ready frame p95 |11.981|12.028|11.591|
| Full after-initial-ready frame p99 |18.676|18.053|17.619|
| Full after-initial-ready frame maximum |77.596|37.810|37.702|

The narrower Door client packet-to-animation interval is now near the saved
18October56.165–62.854ms interval and below the21October141.714–201.968ms
regressed interval. That is evidence of recovery in that interval. It is not
interchangeable with107–151ms total submit-to-animation, and package, producer,
content and camera differences prevent treating the old/current figures as a
controlled same-source A/B. My short update omitted this useful narrower
comparison; saying only “recovery remains open” concealed that distinction.

Total Door/Move feedback still misses the sub100ms minimum/sub50ms goal in
these runs. A frame median below10ms does not satisfy the100+FPS/no-freeze
objective when p95 exceeds10ms and maximum frames reach38–78ms. The largest
spikes contain only about5–7.5ms of measured Play CPU; the rest remains
unattributed. Calling that remainder lighting, shaders, driver or backend work
would be speculation.

The current reducer's `world` timing includes actor/item input capture before
the actual world fold, unlike the old separate phase layout. It cannot be used
as an exclusive World.fold duration or compared directly to the old `world`
label. No additional timing claim is derived from that mislabeled scope.

Exact raw paths, interval definitions, full frame distributions and phase rows:
[current measurement ledger](../../.runtime/client-owned-closure-20261022/performance-baseline/measurements.json)
and [three-run process/exit receipts](../../.runtime/client-owned-closure-20261022/performance-baseline/summary.json).

The final already-running history/Studio group completed all12 invocations /
34,980 assertions naturally0, without script/engine errors or owned leftovers.
It covers actual history modes, material transitions, appearance, navigation,
transport, checkpoint replay and preview controls. Its explicit preview
availability was2822.808ms fresh,214.589ms changed zoom,2250.176ms reset; all
miss200ms. These are64/52-key four-view demand measurements, not ordinary
one-view UI opening latency. This group does not qualify the full185-enabled
GPU inventory,188-production replay sweep,11-live inventory or every interaction.
[Preserved current group](../../.runtime/client-owned-closure-20261022/initial-gpu/summary.json).

An earlier Protection loop's `publish_ms=14039.559` was also at risk of being
misread as14seconds of preparation. Actual first readiness from request was
66.246ms;13973.313ms followed before publication at the loop's Out boundary.
That intentional residence must not be used to explain the separate90s
installation stalls. The old interrupted188-case run completed89 cases,
84passing/5failing, including four installation timeouts; it remains incomplete.
The later successful fresh-process controls did not establish an accumulated
process fix.

## Why the work did not close

1. **I used the wrong completion boundary.** Constructors, adapters, assignments
   and provider counts were repeatedly presented as progress toward finished
   integration without closing ordinary receiving, lifetime, history, removal,
   seeking, loops and actual player interaction at the same source cut.
2. **I preserved names more reliably than computational limits.** Keeping the
   shared renderer and scheduler did not prevent repeated discovery, full-store
   traversal or serial preparation barriers inside their callers.
3. **I measured the user outcome too late.** Source repairs and functional checks
   accumulated while fresh comparable Door/Move/frame/preview evidence was
   missing. This allowed “recovered mechanisms” to sound like “recovered speed.”
4. **Validation became an unfinished tail.** There were many useful checks, but
   historical, focused, current-producer and current-package receipts were too
   often discussed together. The mixed historical230/230 result did not qualify
   the newest package. Native process exits and engine errors are part of the
   result, not optional details after passing case markers.
5. **I did not consistently honor batch execution as an outcome strategy.** The
   human repeatedly requested coherent content batches and later validation.
   Narrow example closure and repeated investigation/checkpoint cycles still
   displaced finishing the broader lifecycle inventory.
6. **External requests became too prominent.** Delivered backend/Factory work
   was sometimes still described as missing, and real external defects were
   allowed to dominate updates while client-owned outcomes, coverage and speed
   work remained. Those dependencies did not justify stopping independent work.
7. **Reporting overstated confidence.** Near-completion percentages, stale
   dependency prose and the repeated “four human-rejected effects” statement
   were unsupported. All art/audio remained pending human review. Quietness,
   interval starts, loop waiting and current-versus-historical provenance also
   needed more precise presentation.
8. **Parallelism was not enough by itself.** Independent reviewers found real
   issues, but source reviews/private patches did not produce a finished runtime
   checkpoint automatically. I remained responsible for adoption, sequencing,
   measurement and closure; the agents were not the reason to stop working.

## Exact stopped state

- The human canceled implementation and qualification. Both running source
  reviewers were interrupted; the event agent had already finished its private
  proposal. No sub-agent is continuing implementation.
- The final native group had already completed normally before cleanup. No
  owned Linux runner or native Godot process remained to terminate. The
  [cancellation receipt](../../.runtime/client-owned-closure-20261022/cancellation.json)
  preserves that result; no other preview/process was targeted.
- Automation `finish-ndclient-authoring` is confirmed `PAUSED` in its existing
  automation.toml. It has not been resumed.
- HEAD remains `d6fffec8`, branch `codex-authoring-schemabump`. The preserved
  `d5d2ff1d` “almost disaster” checkpoint is untouched. There was no reset,
  rollback, new source commit, push or package replacement at cancellation.
- During this last continuation no production implementation or test source
  was changed. The remaining-work priority/measurement notice and this
  post-mortem are documentation edits. Existing changed generated diagnostics
  remain as they were; they were not discarded or swept into a commit.
- The six-case positive-outcome proposal is private and **unapplied/unrecorded**:
  one legal enhanced-Goblin obstruction/fall setup, four predeclared ordinary
  stabilization seeds4–7 and one native ranged-Shield exchange. It guarantees
  no outcomes. Earlier failed originals are unchanged. The three positive
  duties remain open, even though their consumers have source implementations.
  [Frozen proposal](../../.runtime/closing-repairs/positive-outcome-closure-20261022/README.md).
- The two-file accumulated-cost/first-ready diagnostic patch is private and
  **unapplied**. A completion-cursor idea and further preview reductions were
  still being investigated when interrupted. None is an implemented stall or
  speed fix. [Frozen diagnostics](../../.runtime/closing-repairs/accumulated-studio-cost-20261022/README.md).
- Whole-current native/live closure, accumulated-process installation stalls,
  responsiveness/frame/preview targets and remaining history permutations stay
  open. Source assignments/dispositions do not establish visual/audio acceptance.
- Exact delegated Stone-partial and Ice-destruction issues remain in the existing
  [Factory](../FACTORY_REVIEW_2026-10-20.md) and
  [backend](../BACKEND_CONTENT_BLOCKERS_2026-10-20.md) ledgers. This post-mortem
  does not create new requests, inspect their agents or claim later deliveries
  are absent. Independent Arcane placement and creature/art/audio boundaries
  retain their existing recorded status; they are not explanations for the
  client-owned work that remained unfinished.

No implementation is authorized to resume from this document. The human ended
this work; the record preserves what exists without claiming the task is done.


## Bounded integration after the human's follow-up request

The human subsequently authorized only integrating the two reviewed pending
proposals, committing, repeating timings and updating this record. The broader
queue and heartbeat remain stopped/paused. Source is now applied in the existing
NativeStartup/Studio owners plus the scenario data registration/helper. The
first proposal supplies six legal outcome scenarios; the second exposes actual
global completion-scan work and distinguishes first readiness from loop
residence. Neither changes the scheduler, clock or renderer, and neither is a
completed performance optimization.

The new scenario proposal contained a real command-ID mistake missed in source
review: `action.feature.action_surge` was not offered. The actual pinned native
registration and preserved available/affordable Choices name
`action.class.fighter.action_surge`. Only that literal in command/subjects/
requirements and a fresh `_public_v2` case ID were corrected. Seed, actors,
attacks and all other steps stayed fixed. The failed first original is retained.

The fixed initial six-original group and one mechanically corrected Shield
original are imported into the existing Library with their original provenance:

- Both seats prove successful obstructed Shove, then a real10ft fall onto the
  newly freed support,5Bludgeoning leaving2HP, and the surviving Goblin's Step.
- Seed7 proves ordinary stabilization: death-save rolls3,18,4,12,19 produce
  the actual third-success Life transition, without a natural20 or healing.
  Seeds4/5/6 naturally ended in death and remain failed originals.
- The corrected Shield route legally completed, but its four attacks did not
  produce the required Shield reaction. That original remains failed; no
  further attempt/seed search was launched. Positive ranged Shield stays open.

This is original public-fact proof, not native output/art acceptance for those
new cases. All seven originals remain inspectable:2recorded/5failed.
[Exact raw branch proof](../../.runtime/closing-repairs/positive-outcome-closure-20261022/positive-outcome-proof.json),
[initial group](../../.runtime/originals/positives1/index.json),
[corrected Shield](../../.runtime/originals/positives2/index.json).

The single existing fast batch passes200/200. The two affected native processes
pass10,988 assertions (Studio Transport61; existing eight-case Studio replay
10,927), with natural exits0, zero script/engine errors and no owned leftovers.
Functional runs overlapped CPU work; they are not quiet timing evidence.
No deadlines or assertions were changed, and the fast batch was not repeated
for the three Python action-ID literal corrections.
[Fast batch](../../.runtime/tests/20261022T104227.508507Z/summary.json),
[affected native batch and exact source](../../.runtime/client-owned-closure-20261022/adopted-affected-gpu/summary.json).

Source checkpoint **2a094492e85f72caaab5dce525791be44f0028e9** commits the four
implementation/data files and both documentation records. The prior cancellation
statements remain historical; the two reviewed patches are now integrated and
committed. No completion-cursor, further preview optimization or broader
implementation was added.

### Completed retiming on committed2a094492

All preceding owned CPU/GPU jobs had finished before these timed windows. Three
serialized fresh native GUI Gallery runs repeated the same five commands,
1600×960 view, camera12, pinned9f engine and complete530Factory package. The
source files stayed identical to committed2a094492. Each run passed83 checks,
with natural exit0, zero script/engine errors and no owned leftovers. Their
before/after native Godot snapshots are empty; no external process was closed.
This is not continuous whole-host contention monitoring or OS/driver-cold testing.

| Actual submit → first sampled animation,ms | Previous three-run median | Committed retime1 | Retime2 | Retime3 |
|---|---:|---:|---:|---:|
| Door |133.893|112.045|110.202|106.010|
| Move |139.151|122.768|126.322|121.981|
| First Fireball |110.382|96.522|103.502|103.171|
| Second Fireball |126.436|117.569|112.594|114.273|

| Complete after-initial-ready frames,ms | Retime1 | Retime2 | Retime3 |
|---|---:|---:|---:|
| p50 |7.899|7.022|6.844|
| p95 |11.895|11.293|11.099|
| p99 |17.249|17.109|15.974|
| Maximum |43.940|34.812|35.569|
| Initial ready observation |1173|1127|1355|

Initial readiness is a separate observation, not Studio case-switch latency.
The four-view preview process also exited naturally0,352checks/no errors or
owned leftovers. Its exact work scopes remain distinct:

| Preview availability through actual postdraw | Prior before-patch observation,ms | Committed retime,ms |200ms target |
|---|---:|---:|---|
| Fresh,64keys |2822.808|2479.001|Miss|
| Changed zoom,52keys |214.589|174.283|Pass for this batch only|
| Reset/reload,64keys |2250.176|2088.833|Miss|

Door/Move remain above100ms; frame tails and cold/reset preview availability
still miss their targets. Several observed values are lower, but these patches
add scenario data and instrumentation rather than an implemented performance
optimization. Three sequential observations with no cache flush/randomization
do not establish that the diagnostic patch caused the difference. The source
completion-scan and old accumulated-process stall causes remain unclosed.

[Complete current process receipts](../../.runtime/client-owned-closure-20261022/adopted-retime/summary.json),
[concise exact measurements](../../.runtime/client-owned-closure-20261022/adopted-retime/measurements.json),
[offline raw/phase/frame comparison](../../.runtime/closing-repairs/accumulated-studio-cost-20261022/adopted-retime-comparison.json).
The offline comparison reads preserved records only; it launches no additional
benchmark, server or client. Its nested phases are inclusive and not added as
exclusive time. Source/package/producer and command joins remain explicit.

This completes the bounded integrate/commit/retime/document request. The broader
implementation/qualification queue remains stopped, the heartbeat remains
paused, all art/audio remains pending human review, and no additional work is
resumed by this record.
