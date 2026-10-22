# Client rendering migration: regressions and execution failures

21 October 2026. Written after the human stopped implementation and requested
this post-mortem. This is an audit, not an implementation plan or permission to
resume. No fixes, builds, recordings, rendering runs or tests were launched for
this audit. All artwork and audio remain unreviewed.

The expanded human request audits every implemented Opus speed path against
Sol's starting source and identifies introducing changes. See the linked
[Opus performance audit](OPUS_PERFORMANCE_REGRESSION_AUDIT_2026-10-21.md).
Section8 incorporates the independent shared-path review supplied afterward;
the performance audit also checks the later Astra history review.

## The task I failed to preserve

The requested result was a cleaner, resource-driven authoring setup using the
shared renderer, preserving the established picture, timing, scheduling,
lighting and responsiveness. A cleaner source layout did not authorize slower
interaction, broken camera views, lost effects, or a less usable Studio.

The approved plan explicitly required preserving native 2D lighting/normals,
colours, depth/sorting, shadows, tint, wall behavior and body/audio timing. It
also prohibited presentation holds, invented outcomes and a second rendering
framework. Keeping the existing module names did not preserve those guarantees.

I let source integration accumulate ahead of demonstrated runtime preservation.
I also repeatedly used provider implementations, resource counts and focused
passing examples as stronger completion evidence than they were. The real
client performance regression below is my responsibility; the faster server
does not explain it away.

Authority: [approved plan](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/SCHEMA_AUTHORING_CONDITIONS_STUDIO_PLAN_2026-10-19.md:58)
and the human's accumulated instructions in this chat.

## Frozen state at the stop

- Client HEAD: `fc84da2af36c33d5ccda832f3255c19987f18e01`, branch
  `codex-authoring-schemabump`. Installed complete Factory package:
  `runtime-speed-completion-20261021-82a271b677ff9604`. Its delivery and receiving
  changes remain uncommitted; the previous committed package is8dd.
- The latest quiet performance traces are older8dd traces. There is no quiet82a
  performance result and no basis for claiming that its integration restored
  responsiveness.
- Root stopped the current native process and its Python queue on the human's
  instruction. No client Godot reader remained after cleanup. The user's
  separate previews were not stopped. The implementation heartbeat is paused.
- The243-row queue contains48 completed invocations, one human-interrupted
  invocation and194 unstarted invocations. The interrupted package check printed
  6,402 assertions/zero failures, then was forcibly stopped with exit255. That
  exit is not a naturally occurring crash or a successful qualification.
- The three sub-agents finished their assigned source-only work. Their pending
  proposals were not applied. No implementation rollback or new commit was
  made after the stop. This post-mortem and the remaining-work stop notice are
  documentation changes only.

[Stopped queue and original results](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T203343.842010Z-current82a-runtime-tail/summary.json).

## 1. Door response: confirmed client regression

The older roughly61ms result was packet arrival to the first observed body
animation. It was not total user response. That distinction is necessary for
correct arithmetic, but it does not excuse the regression: the same client
interval has become substantially slower.

| Saved interval, milliseconds | Earlier18October, three quiet runs | Latest quiet21October, three runs |
|---|---:|---:|
| **Client packet framing start → first body animation** | **60.772 /62.854 /56.165** | **149.001 /201.968 /141.714** |
| Actual command submit → first body animation |198.427 /186.851 /236.064|203.888 /266.445 /190.565|
| Full gesture → first body animation |216.453 /201.389 /256.168|219.859 /282.872 /202.518|
| **Backend dispatch, independent server duration** | **83.368 /83.071 /83.765** | **32.358 /43.275 /32.706** |
| Client packet admission |19.087 /23.545 /17.950|5.981 /8.718 /5.752|
| Client canonical fold |15.015 /15.535 /16.495|26.486 /28.247 /24.737|
| Presentation compilation |4.343 /4.406 /4.776|8.687 /11.019 /9.688|
| Opening metadata ready → first body animation |18.305 /15.442 /12.493|103.773 /146.343 /97.345|

**The server improved while client work and waiting grew.** Reduced server
time partly concealed the increased client time in the total response. The
packet admission cost also improved; this was not a blanket regression in JSON
parsing. The larger increase is after the opening is prepared. Fold/world and
compiler costs also rose.

### Source-proven preparation/cancellation defect

The existing selection metadata owner serializes one worker task. It accepted
cancellation of an offered-choice preparation but continued an expensive
aggregate body-path phase. The next selected Door request waited for that same
task to finish:

| Saved selection job interval, milliseconds |Run1|Run2|Run3|
|---|---:|---:|---:|
| Cancelled offered job's aggregate body-path work |102.772|130.127|97.998|
| Selected Door job's own work |1.089|1.716|1.019|
| Selected Door job's queue wait |111.974|170.299|102.414|

In runs1/2 the worker knew it was cancelled before it entered the aggregate
body-path call. The old branch lacked the check at that boundary. Run3 was
already inside the call. `Characters.sheet_paths` traverses layers and
clip×layer metadata loads without cancellation checkpoints.

This means optional background work was allowed to obstruct the newly selected
action. Moving work off the scene thread did not make that serial dependency
harmless. The queue wait overlaps transport and folding; it is not an additional
addend or an exclusive explanation of all opening-to-animation time.

Boundary checks were added in `24a993f0`. They do not interrupt work already
inside `sheet_paths`. Cancellation within those existing load boundaries is
only a source proposal; it has not been implemented. Neither change has a
subsequent quiet timing result. **Door responsiveness is not repaired or
qualified by the current evidence.**

Sources: [selection worker](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/selection_media.gd:222),
[body-path traversal](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/characters.gd:178).

The old/new runs have different producer, content/package and camera revisions
(18 versus12). They establish increased client time, but do not isolate the
single introducing commit for every additional millisecond. There was no new
benchmark or speculative attribution to the backend, GPU or driver.

[Offline derivation with six original paths, timestamps, server rows and job clocks](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/material-runtime-integration-20261021/door-postmortem-evidence.json),
[original latest quiet comparison](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T175335.405738Z-r6-current-three/quiet-r6-comparison.json).

### Later trace analysis: a second, larger playback regression

The expanded audit also establishes real freezes after animation starts:
Door media holds627.012/868.700/603.776ms and first room-Move holds
350.546/353.056/365.354ms, versus zero in the saved old routes. Actual source
ages stop near0.25seconds. These are separate from initial response latency
and are not newly demonstrated longer authored clips.

The delayed required-worker leaf is environment_commit_updates: Door42.264ms
in the nearest pre-Sol saved profile becomes629.598–857.218ms; Move17.398ms
becomes581.752–599.312ms. In291e092c, residue integration made the old local
tile/object metadata call repeatedly construct the entire visible-cell set,
even for partial states without residues or tiles. This is source-confirmed
new repeated global work inside the actual slow leaf. Different content/source
cuts prevent assigning its entire measured increase to that expression.

The earlier coverage/clock gate remains unchanged. It waits because required
client metadata arrives late; the early false native/path flags do not prove
Factory loading failure. Full source/commit/evidence detail is in the
[Opus audit](OPUS_PERFORMANCE_REGRESSION_AUDIT_2026-10-21.md) and
[environment note](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/environment-metadata-regression.md).

### Other measured performance failures

- The separate209–212ms `native_prepare_resources` startup leaf disappeared in
  the later quiet runs. That was a real local improvement, not proof of fast
  Door response. Initial readiness nevertheless increased from883/923/883ms
  to1014/1367/998ms. Startup maximum frames were73.724/96.531/69.826ms.
- After readiness, maximum frames were55.680/47.080/50.918ms. The earlier
  comparable maxima were50.293/45.171/45.370ms. The frame target remained unmet.
- The Fireball source was missing from offered-spell preparation candidates.
  The existing offered-body branch enumerated native actions but omitted native
  spell selections. Warming the actual Fireball lifecycle consequently occurred
  late. Its private draw coincided with the maximum frames and six added
  specializations. That does not identify exclusive shader-compiler time.
  Candidate joining was corrected in24a993f0; its timing benefit is unmeasured.
- Main-RD/pipeline and constructor flags supplied with82a remain unresolved
  costs. Installing worker alternatives does not establish that the integrated
  client meets a frame allowance. The latest functional runs were nonquiet.

## 2. Actual rendering and lifecycle defects

These are real client integration failures, not conclusions inferred merely
from an obsolete test. A repair below has only its stated evidence. For several
older defects the introducing combination was not bisected; I will not invent
an introducing commit or relabel them all as new21October changes.

| Defect and consequence | Source cause / ownership | State and evidence at stop |
|---|---|---|
| **Camera rotation produced narrow, disconnected wall strips.** | Reused Studio panes kept static geometry in their previous camera basis, while ReplayPanes directly relabelled their quarter. Unchanged groups were then incorrectly reused beside newly oriented groups. | Already present at9b73/Opus7faf78fb; corrected through ordinary prepared view publication in291e092c. Actual walled Gallery:269 checks,22 failed before and0 after. The user saw a real rendering defect that existing evidence had missed. |
| **Visible floor residues could become remembered/dim after camera/scenery refresh.** | The refresh call omitted the new residue index although preparation supplied it. Two consumers of the same visibility function disagreed. | Refresh corrected in291e092c. Source repair is present; that does not certify every residue/view combination. |
| **Immediate Freezing Sphere explosion used caster elevation on raised target terrain.** | The new immediate-blast projection supplied position without its ground elevation; downstream placement retained the caster height. | Introduced immediate-blast path in291e092c; target support forwarded in5258b326. Current Event family1848/0 is bounded affected evidence, not an all-elevation artwork review. |
| **Restored shadows could retain the wrong source frame.** | Both frame-only UV update paths changed caster geometry without invalidating Godot's cached shadow atlas. Full binding already performed the required notification. | Omissions already present at9b73/813d21f6/bd3c20f7; both repaired using the existing instance notification. Selected actor preparation/restoration9022/0; earlier exact-pixel failures retained. |
| **Some valid Acid/Ice native sources contributed no pixels.** | Preparation ignored explicit `area_mask=false` while sampling respected it, installing an unpopulated clipping interface into already partitioned sources. | Shared opt-in guard repaired. Later Acid34/0 and current82a Event1848/0 are scoped evidence. No pixel tolerance was widened to conceal the defect. |
| **Historical body/material output could stay unready.** |24 suspended captures were retained without resuming their actual existing owner after the requested history key matched. Their draw frames remained-1. | Existing Capture.resume used; selected six-original material/history cohort16432/0. This does not prove every overlap/permutation. |
| **Reverse analytical effects disappeared while sampling backward.** | The presenter hid analytical reverse samples until after the draw that needed them. | Ready absolute reverse samples restored before drawing; selected Font replay13211/0. No replacement clock or postponed authoritative event was introduced by that repair. |
| **A temporarily unavailable authored socket permanently poisoned a presenter.** | Null per-frame pose markers were treated as permanent missing-source errors, even when the actual later frame had a valid marker. | Shared transient handling repaired for actual Font/Divine Smite witnesses. Unsupported current-frame placement remains omitted, without inventing a socket. |
| **Finite body-layer ownership ended one floating-point step too early.** | Planning used `group+(local+duration)` while display used `(group+local)+duration`; Earth playback exposed the mismatch at a Shield layer boundary. | Shared endpoint arithmetic unified in24a993f0. Actual four-elemental cohort28661/0, including eight intrinsic gestures. Earlier failed receipt remains. |
| **Currently observed finite traps could be suppressed.** | Client World readers treated `apparent_presence=false` as absent current membership. That field describes memory/absence behavior; the current disclosed spatial-effect membership was already authoritative. | Client semantic correction present. The backend handoff explicitly identified this client mistake; requesting more producer data would not repair it. |
| **Existing public setters were not receiving their actual declared operands.** | Generic input forwarding/preparation did not fully honor the selected public contract, producing native errors for Animal Friendship/Hideous Laughter and missing contribution in other consumers. | Shared forwarding corrected; affected originals passed without the earlier nine native errors. Earlier internally passing case markers did not make those invocations clean. |
| **Selected effects named the wrong immutable preparation coordinator.** | Client Resources pointed at a different Readiness Script/bank than their constructors consumed: the earlier28-use correction, nine input-reduction uses and three wall uses were incomplete assignments. | Resource/source corrections applied. These were client assignment defects, not missing Factory APIs. Publication alone did not qualify their native output. |
| **A retained source preparation could deadlock when sibling paths were added.** | Existing source A owned admission; newly required uncached B paths made `loading.pending>0`, preventing A from being stepped and releasing admission. | Current uncommitted82a receiver steps only its existing owner before requesting sibling paths. Native35/0 covers that exact expansion plus concurrent recorded loading; cancellation/performance as a whole remain unqualified. |
| **New Wind constructor transport was initially incompatible with the public argument.** | Generic transport supplied phase/operands, while the actual public constructor takes `input.wall`. The build validator also whitelisted only two old approach labels. | Literal resource `constructor_input.argument` and generic declared-contract admission applied in the uncommitted batch. Initial failed publication preserved; affected abilities publication passed. Full native Wind closure was not completed before the stop. |

Key evidence:
[camera before/after](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/material-runtime-integration-20261021/camera-before-after.json),
[camera analysis and saved images](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/STUDIO_CAMERA_REUSE_DEFECT_2026-10-21.md),
[shadow source cutoff](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/material-runtime-integration-20261021/source-cutoff-shadow-templates.json),
[mask source cutoff](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/material-runtime-integration-20261021/source-cutoff-area-mask.json),
[historical and affected results](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/REMAINING_WORK_2026-10-20.md:292),
[backend identification of the client trap mistake](/mnt/c/Users/tommaso/Documents/Dev/dnd_engine/agent_docs/BACKEND_TRAP_GLYPH_HANDOFF_2026-10-21.md:45),
[current82a results](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T203343.842010Z-current82a-runtime-tail/summary.json).

## 3. Studio regressions and misleading evidence

### Still open: direct effect Mute/Solo addresses the wrong ID

Commit291e092c changed `Studio._diagnostic_id` to return `parent_id` for every
eligible presenter. That is appropriate for derived light/material inspection
channels, whose parent is their real source. A direct finite component instead
has its own ID, such as `6:48:native_effect:*`, and parent event `6:48`.
Play filters exact component IDs. Muting that event key cannot mute the selected
direct effect; solo can exclude the direct effects instead of isolating it.

This is a newly introduced production UI bug, proved by the actual current
Frenzy original and exact source identity chain. No GPU reproduction was run in
the post-mortem. The four-file proposed repair is peer-reviewed but **unapplied
and unexecuted**. It must not be reported as fixed.

Sources: [bad redirect](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/studio.gd:428),
[direct component IDs](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/components.gd:205),
[exact Play filtering](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/play.gd:760),
[derived channel parents](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/native_spell_channels.gd:15).

### Other demonstrated Studio and evidence defects

| Failure | Cause and consequence | State at stop |
|---|---|---|
| Library disabled otherwise playable historical originals. | Eligibility required exact backend commit identity, conflating compatible wire playback with current-producer qualification. Earlier index:312 stale recordings/19 failed cases; normal Play was unavailable. | Exact wire admission and original provenance separated in291e092c. Current library372 cases/369 recorded/3 failed. Compatible playback is not fresh current-engine evidence. |
| Native spell authoring gaps were absent from the worklist. | Spell audit inspected legacy recipes but omitted the native cue inspection already used elsewhere. The tool could miss the very constructors/inputs/ownership gaps it was meant to expose. | Native default and variant cues now audited. The old audit's apparent completeness was false. |
| Explicit same-clock seek retained a stale audience anchor. | An early return happened before clearing the retained anchor for a new navigation intent. | Corrected in c76e2139; relevant native navigation evidence retained. |
| Ordinary thumbnails/waveforms could starve behind composed previews. | Queue polling returned at a composed job that could not start, leaving eligible ordinary work behind it. | Corrected in c76e2139 using the existing queue. No new preview subsystem. |
| Follow could target a row outside the drawn timeline. | Row selection/scroll changed, but exhausted thumbnail budget prevented publication of current row geometry and hit-testing. | Existing TimelineView repair is applied but uncommitted. Current Follow gate passed; mixed Gallery126 checks still had four independent role/ID predicate failures. Whole Gallery acceptance remains incomplete. |
| Silent transport diagnostics were classified as audio output. | Zero starts/no PCM receipts were counted with playback witnesses. | Classification corrected; these do not prove audible output, timing, mix or review. Historical tooltip/report prose is not stronger evidence than counters. |
| Live aggregation could call a crashed process safe. | Native exit was recorded as metadata but excluded from `runtime_safe`. Successful case markers could conceal a subsequent crash. | Exit0 is now required in5258b326. Old reports must retain their original provenance and cannot be treated as clean on case assertions alone. |
| Coverage retained repaired Frenzy/Counterspell blocker claims. | Hardcoded report prose lagged delivered sources and actual consumers. | Current source reporting corrected; older generated snapshots remain historical. A generated worklist was not a reliable completion boundary. |
| Artwork review status was fabricated. | Older client code literally hardcoded Aid/Bless/False Life/Sacred Flame as REJECTED, and documentation repeated that supposed human decision. The human had not reviewed the artwork inventory. | Hardcoded subset removed; README corrected byfc84da2a. All artwork/audio remain unreviewed. This was a reporting and product-status error, not an art verdict. |

## 4. Authoring/publication mistakes that source presence concealed

The initial elemental intake declared original normals while ordinary rendering
requested the global Reference profile. It needed an explicit per-Surface
original policy, not fabricated alternate normals. Eight authored intrinsic
BodyUse entries also lacked their build disposition, so publication omitted
them. Earlier body checks did not assert those actual gestures. Only the later
compiled-track and acknowledged source/frame controls established their output.

These were client intake/publication omissions. Delivered sprites and passing
ordinary body tests did not mean the new action authoring was integrated.

Source peer review also missed an invalid empty `@export_enum` argument in that
profile change. Root found the parse error in publication logs despite the
wrapper's exit marker. The declaration was corrected before the passing
publication; the earlier marker was insufficient evidence.

Imported `silhouetteDust` and140ms lead-in are now explicit inactive studies.
Retaining values and source pointers does not implement their particle/timing
behavior. They are not accepted art decisions. This audit has not established
an older active consumer for those fields and does not invent one to label them
proved visual regressions.

## 5. Test regressions I introduced and older broken controls

The current failed results must remain failed. Their causes nevertheless need
accurate classification: fixing a mistaken predicate does not repair rendering,
and a predicate failure is not proof that a source disappeared.

| Current failed invocation | Actual finding | Unapplied work / limit |
|---|---|---|
| Gallery checkpoint126/4; native spell batch145/37; Library33/4; source preview4/1 | New/current gates compared canonical behavior IDs such as `spell.fireball` against the unchanged short source selection ID `fireball`. Generic native components also legitimately lack spell_id. The migrated Library/preview predicates were my newly introduced harness mistakes. They falsely reported missing tracks before TimelineView was involved. | Exact four-gate79-line repair peer-reviewed, unapplied/unexecuted. Counts, pixels, clocks and real missing ranged-Shield duty remain strict. No claim that these UI paths now pass. |
| Requirements2015/263 |130 recipe,130 occurrence and3 revision comparisons used a frozen extractor that emits empty raw source pointers. Current typed Resources preserve the known caller root. Current cached/uncached/offline equality already passes. | Narrow one-test provenance correction peer-reviewed, unapplied. Frozen extractor remains unchanged; five corruption controls proposed. These failures do not establish263 broken effects. |
| Condition material22/20 | Old test shader still called two-argument `character_material`; current function takes untinted RGB as a third argument. Outline setup also omitted current preparation, IDs and the source-parameter ledger. Invalid setup makes those pixel comparisons inconclusive. |50-line setup proposal exists, unreviewed/unapplied. Independent Pygame oracle and tolerances unchanged. Correct current production material parity has not been established by this invocation. |
| Character geometry render, exit-9 | Test uses old Sun/Omni lighting for the approved unshaded Canvas-receiving material, omits descriptor admission, and lacks its generated numeric oracle input. | No replacement patch applied. The invocation is failed; this diagnosis does not establish all current normals are correct or explain every aspect of exit-9. |
| Door-state render4/1 | Supplied Gallery original contains four actual furniture/torch destructions and zero door destruction. The test expects a different old passage/remnant recording. | Missing required genuine original. No destroyed-door outcome, synthetic journal or renderer-input fixture was substituted. This invocation does not prove a door renderer regression. |
| Frenzy/Blood old controls | Selectors and fixed clocks name retired presenters rather than current source/UUID/flight/deposit ownership. | Peer-reviewed current-contract migration remains unapplied and unexecuted. It proves no additional runtime repair. |

Additional source-only media/geometry migrations and four historical equality
retirements are also pending. **No test was retired, promoted or altered after
the stop.** A retirement proposal explicitly says retired is not passed, keeps
the historical scripts/oracles and maps current responsibilities to independent
successors. It is not an accomplished runtime result.

The latest queue's EffectPackage exit255 is human interruption. Separate earlier
native access violations after passing assertions are real unresolved exits;
the21October Studio transport and delayed-server records have Windows
`0xc0000005` events. `ntdll.dll` is the faulting module, not a demonstrated root
cause. The latest Library invocation also exited5 with teardown diagnostics.
Successful intervening exits do not explain these failures or establish safe
teardown. No backend/Factory cause has been established.

[Native exit evidence](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/agent_docs/STUDIO_NATIVE_EXIT_2026-10-21.md),
[latest original failed results](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/tests/20261021T203343.842010Z-current82a-runtime-tail/summary.json).

## 6. Why execution kept producing work without closure

1. **I treated working pieces as completed integration.** A shared adapter,
   selected resource or positive isolated image did not establish the complete
   lifecycle, ordinary gameplay, overlap/restoration, Studio behavior or speed.
   Reporting those pieces as near completion made the true unfinished tail
   invisible to the human.
2. **I did not preserve a reliable runtime boundary while expanding content.**
   New bindings, source preparation and cache ownership accumulated across
   large checkpoints while camera, first-use and interaction failures remained.
   Source commits made the work reviewable; they did not make it stable.
3. **I optimized a leaf and overstated what it meant.** Removing209ms from one
   startup scope did not establish low Door latency. Packet-only, full gesture,
   actual submit, readiness and frame maximum are different measurements. The
   client-only regression was real even after those scopes were corrected.
4. **I treated off-thread work and a nominal budget as guarantees.** A serial
   cancelled metadata task still obstructed selected work. Indivisible source
   construction and first native draws could still exceed a frame budget.
5. **Tests generated avoidable churn.** New predicates were written against the
   wrong source ID contract; old shader/preparation controls were not migrated
   with their consumers. Large assertion totals and fast passes did not expose
   the user-visible camera defect or establish whole-game responsiveness.
6. **The review surface was itself unreliable.** Stale commit-based admission,
   missing native audit coverage, wrong mute IDs, blocked previews and audio
   misclassification prevented Studio from serving as a trustworthy checklist.
7. **I let stale status become apparent authority.** Old blocker prose persisted
   after deliveries; a fabricated four-effect rejection status narrowed a human
   review that had not happened. Some requests concerned client use of already
   available contracts. Those were not grounds to keep requesting producer work.
8. **I did not follow the requested execution priorities consistently.** The
   human repeatedly asked for schema/content families, data-driven decisions,
   renderer preservation and grouped checks. Repeated test/harness repair and
   narrow examples consumed attention without closing those obligations.

These are execution failures, not a justification for more framework work,
more content, wider pixel tolerances, invented outcomes, or additional external
requests. No such work is authorized by this document.

## 7. Finished sub-agent state and pending artifacts

| Agent | Finished work | State |
|---|---|---|
| `event_consumers` | Frenzy/Blood current-contract controls and direct-source Mute/Solo fix; four-file393-line scratch and source-cause README. | Peer-reviewed; unapplied/unexecuted. No jobs or production writes. Finished. |
| `studio` | Two media/scene control migrations; four-gate source-ID repair; condition-material setup proposal; geometry-render and missing door-original diagnosis. | First two peer-reviewed; all unapplied. Condition proposal unreviewed. No jobs or production writes. Finished. |
| `plan_review` | Plan/antiOOP/source reviews, exact requirements provenance diagnosis, historical equality proposal, Door fact check and cancellation-boundary analysis. | Source-only work finished. All proposals unapplied; no jobs or production writes. |

Scratch evidence:
[Event report](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/frenzy-blood-current-contracts/README.md),
[Plan report](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/plan-review-post-mortem.md),
[source-ID repair](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/native-source-selection-identities/native-source-selection-identities.patch),
[media/geometry proposal](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/current-media-geometry-controls/README.md).

## 8. Independent shared-path review, verified against source/history

The additional review was checked read-only. These open defects are not fixed
by documenting them. Priorities retain the supplied review's P1/P2 labels.

| Priority / finding | Verified source chain / consequence | Introducing history and limit |
|---|---|---|
| **P1: hidden/unavailable coating can retain its external weapon treatment.** | Effects.hide hides its root and withdraws actor_context. Weapon registration/endpoint refusal can return before source input synchronization/sampling. The claimed material is on the actor's displayed weapon, outside that root; its `_hide`/invalid-binding/clear/tree-exit release is not invoked by parent visibility. A prior treatment and exclusive claim can remain. | ba5d0262 added this hide function after Sol started, before equipped-source integration. d4eb31de selected the first equipped FireBlade candidate;2bb7ede2 expanded equipped sources;291e092c added six global coating holds without the missing withdrawal. Some refusal paths do release, and actual destruction releases ownership. No claim of a permanent leak or universal failure; no GPU reproduction. |
| **P1: Mute/Solo ID mismatch.** | Direct presenters need component IDs while derived light/material rows need their source-parent ID. Blanket parent routing breaks direct effects. | Introduced291e092c; already detailed in§3. The pending repair is unapplied. |
| **Native-light inspector has a separate wrong-key join.** | A channel inherits native_spell and receives `<occurrence>:light:<path>` as ID, while renderer diagnostics use occurrence IDs. The generic inspector queries the channel ID and can falsely show `not_sampled_at_playhead`. Menu parent routing does not fix inspection. | Inspector join introduced291e092c; channel identities predate Sol. Actual per-light submission has its own identity; parent diagnostics alone would not establish per-light output. No illumination failure inferred. |
| **P2: removed tiles do not propagate dirty cells.** | Compiler.apply_delta erases tiles_removed, but Timeline._record_world_changes and _world_candidate omit those keys; membership-order logging omits tile removal. Sparse World.prepare_changes cannot revisit the retained floor/residue row without another dirty/full route. | Became active119ddede, when schema16 removal was added without adapting these old propagation functions. Full rebuilds/other dirty/support/sensory paths can mask it. Connectors can still advance revision, so this is not a blanket no-invalidation claim. Source-confirmed, no rendered removal reproduction. |
| **P2: tile re-entry loses insertion order.** | SDK erases/reappends entered cells. Its final-value delta lets Compiler merge an already-held tile key without reappending; Timeline logs only previously absent insertions. Existing w7 step1 expects0,0→2,0→3,0→1,0; presentation can retain0,0→1,0→2,0→3,0. w14 exposes the same distinction. | Introduced119ddede; already present before24a's sparse-fold repair. Existing recursive Dictionary comparisons ignored order, and later insertion checks excluded held keys. Fixture/source proof, not a new executed test or measured pixel defect. |
| **P2: version switching can retain stale thumbnails.** | Scene version increments Effects.revision, then seeks the same index; memory/composed keys and descriptors omit revision while same-index staging avoids reset. Existing cache hits bypass the correctly keyed disk store. | Mode-change interaction already present at Sol-start9b73, introduced by Opus0529f8ed.291e092c's composed preview inherited it. Applies when the selected approach actually changes; open, no new runtime reproduction. |
| **P2: Automatic Follow misses current row families.** | Effect-owned `motion` rows are absent from both PREVIEW_KINDS and priority. Mechanism world_activation/world_animation rows enter candidates but have priority-1, so unfiltered Follow skips them; a text filter can permit those world rows. | Motion omission introduced2bb7ede2; world-row priority omission291e092c. Separate from layout publication and from actor-camera follow. Open. |

Sources: [external-material hide](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/effect_package.gd:620),
[early weapon refusal](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/native_spell_renderer.gd:403),
[tile propagation](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/presentation/timeline.gd:47),
[inspector join](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/studio.gd:1403),
[thumbnail key](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/thumbnail_cache.gd:150),
[Follow priority](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/studio/timeline_view.gd:271),
[packet/order source audit](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/closing-repairs/opus-packet-path-post-mortem/README.md),
[Studio history audit](/mnt/c/Users/tommaso/Documents/Dev/NDClientGodot/.runtime/postmortem-opus-audit/studio-optimization-audit.md).

The expanded baseline check corrects attribution of several earlier findings:
the slatted-wall quarter bug, shadow UV invalidation omissions, same-clock
retained anchor, exhausted-budget Follow layout, and nonpreemptible selection
body-path loops already existed at9b73. They were real defects found/repaired
during this work, but are not all newly introduced by Sol. New metadata thread/
join/serialization work is traceable to f489896f/5b12fdf6; its isolated share of
the current97.998–130.127ms aggregate has not been measured.

Evidence correction: historical230/230 headless is a join across source cutoffs,
not a fresh single run or qualification of82a. Its rows retain joined-from/log
pointers, but lack inline source/package identities for every row; original
reports/cutoffs are needed. The423,699 count does not prove current native
output, latency or teardown. The latest failed34-spell predicates, old material
harness setup and current native exits remain classified separately in§5.

Ordered condition removal/reapplication, nested result ownership and atomic
journal publication survived the source review. Those retained contracts do
not offset the defects above or justify a renderer rewrite. The identified
failures concern ownership withdrawal, invalidation/order, source/channel
identity, cache invalidation, omitted Follow coverage and lost fast paths.

## Audit limits

This inventories substantiated client regressions, integration defects and
misreporting found in the saved evidence and source history, including repaired
ones. It does not claim an exhaustive pixel comparison of every current effect,
because that comparison does not exist. The194 unstarted invocations, current
live suite, quiet82a performance, full material/history combinations and human
art/audio review remain unqualified. Unexplained crashes and rendering failures
are not cleared merely because some old tests are wrong.

Missing creature bodies, pending dragon geometry/normals and genuine supplied
Factory defects are separate facts. They do not explain the client Door
regression, broken camera publication or wrong Studio IDs. No new delegation or
implementation task is created here. **Implementation remains stopped.**


## 22October main-queue continuation: shared Startup request cancellation

Source-confirmed introducing cut:`d5d2ff1d` (`almost disaster`) adds both the
empty-plan whole-cache prune and current-first-eligible prune in
`presentation/native_source_startup.gd`. The older per-Play request interface
predates them. Its process-owned resource cache serves multiple Studio panes;
a passive/ready retained pane could cancel another pane's actual unfinished
immutable preparation before frame/budget admission. This is a client ownership
regression, not justified extra backend work or a Factory defect.

The bounded repair retains one actual weak requester and exact immutable job
identity, preserving required priority and same-owner withdrawal while releasing
at the existing freeze/exit boundaries. Completed resources/programs, real
occurrences, draw fences and all private clocks remain at their existing owners.
The current real two-caller/threaded-load/drain headless controls pass208
assertions, natural exit0. No registry, scheduler, renderer or loader is added.

The predecessor full188native run retains187passing cases and one Summon Dragon
installation timeout. Its older diagnostics omitted the actual Startup gate.
This source finding/repair does not prove that timeout's cause, attribute old
shutdown dumps or establish quiet performance. The affected/current native
follow-through is separately recorded in
[the single execution inventory](../REMAINING_WORK_2026-10-20.md).
