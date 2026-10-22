# Opus recovery implementation — 22 October 2026

**Human continuation,22October:** the completed structural source batch is now
committed as23e14a2e. The human resumed the held main queue; quiet R6 performance
comparison remains open and does not gate independent content/Studio work.
The earlier recovery-first wording below describes that implementation boundary.


**Latest request: implement the approved [remaining structural recovery plan](OPUS_REMAINING_STRUCTURAL_RECOVERY_PLAN_2026-10-22.md), with explicit Studio optical-context invalidation.**
The source families are implemented in the existing SDK, Studio and shared
preparation/publication owners. The prior eight-file diff remains present.
Their affected sixteen-case cohort passes below; this is not complete current
native/live or performance acceptance. The automated heartbeat remains paused.
The plan-preparation freeze below is historical.

The human explicitly resumed implementation after the four Astra plan corrections.
Recovery of lost responsiveness and behavior takes priority over new assignments.
The immutable starting checkpoint remains `d5d2ff1d` (`almost disaster`).
Authority: [corrected recovery plan](OPUS_RECOVERY_AND_COMPLETION_PLAN_2026-10-21.md).
The plan-only STOPPED statements describe its earlier preparation, not the current
human-authorized execution.

## Further recovery — blood preparation lookup

`BloodRenderer.prepare` now builds a call-local lookup by receiving-field key
on the first actual reveal. Both existing preparation passes use ordered
references to the same retained jobs. New jobs enter the retained list and
lookup together. Matching still requires the exact source identity and equal
after-value; worker startup/join, task readiness, group leases, allocation,
adoption and retirement are unchanged. Empty reveal demand performs no index
scan. This removes repeated linear searches inherited from Opus, rather than
restoring an absent Opus mechanism.

The existing exact Fireball four-view preview control passes 352 checks on
original, candidate and original-control runs. A temporary phase timer isolated
the optional blood preparation phase and was removed after each run. Median
CPU time per profiled frame carrying that phase is:

| Preview / owner (ms) | Before | Candidate | Original-code control |
| --- | ---: | ---: | ---: |
| Fresh / reference Play | 0.2655 | 0.2115 | 0.252 |
| Fresh / composed pane | 0.262 | 0.212 | 0.251 |
| Reset / reference Play | 0.276 | 0.216 | 0.261 |
| Reset / composed pane | 0.270 | 0.213 | 0.254 |

This supports a modest reduction in preparation CPU. It does **not** establish
an elapsed-preview speedup: the original-code control completed faster overall
than the candidate. The profile accumulates calls within each frame; these are
frame samples, not verified individual-call counts. Cumulative CPU totals also
span different frame populations.
The preview and broader performance targets remain open.
[Raw comparison and scope](../.runtime/performance-recovery-20261022/optional-blood/comparison.json).

The [affected checks](../.runtime/tests/20261022T192819.772545Z/summary.json)
pass: kernel cache 2,888, native shape preparation 50,714 and native world
preparation 34. They retain the independent kernel output oracle, copied-value
adoption, source changes, worker completion and group retirement controls.
The subsequent [full fast suite](../.runtime/tests/20261022T192911.725664Z/summary.json)
passes all 208 tests with no leftover test processes.

## Further recovery — decoded world columns

The resumed recovery removes two repeated operations inside `sdk/fold_world.gd`.
An entered-cell population is decoded once and lent to tile-column decoding only
when the two original masks match exactly. Different masks, including unchanged
tile subsets, keep the existing decoder. Object and placement rows retain their
complete defaults and original dictionary key order; native dictionary merges
populate defaults, then script visits only supplied sparse column entries.
Column validation and first-refusal order are unchanged. Accepted negative
sparse-field indices retain the previous lookup behavior: they are ignored,
not interpreted as indices from the end of an Array. This uses call-local data,
without a retained cache or changed wire/canonical state.

The three original schema18 gameplay journals at `20261022T132135.731366Z`,
`20261022T132206.675491Z` and `20261022T132237.332472Z` supply all 21 packets.
The unchanged-pipeline reference matches the candidate's canonical state,
compiled output, recorded transitions and detached public fold: 85 checks / 0 failures.
The object decoder's separate original-column comparator passes 450 checks,
including exact output bytes, input preservation and 11 refusal controls.

Five warm repetitions per recording, followed by an original-code control,
give these medians across the three recording medians:

| CPU interval (ms) | Before | Candidate | Original-code control | Final candidate |
| --- | ---: | ---: | ---: | ---: |
| Door world processing | 13.303 | 12.562 | 13.318 | 12.219 |
| Move world processing | 8.241 | 7.784 | 8.139 | 7.596 |
| Door Journal/reduction interval | 21.837 | 21.088 | 21.943 | 20.592 |
| Move Journal/reduction interval | 19.977 | 19.455 | 19.943 | 18.960 |

These are modest isolated CPU savings. The nested intervals are not additive;
they do not qualify live command latency, frame maxima, preview speed or the
remaining performance targets. The final repeats include the negative-index
compatibility guard; exact 21-packet parity passes again after that correction.
[Inputs, timings and exact comparison](../.runtime/performance-recovery-20261022/entered-reuse/comparison.json).

The [full fast suite](../.runtime/tests/20261022T191211.723633Z/summary.json)
passes 208 tests. After the negative-index correction, the
[affected SDK checks](../.runtime/tests/20261022T191803.551050Z/summary.json)
pass again: fold vectors 1,257, canonical reuse 87, sensory journal 589.
The two added negative-row controls use actual nondefault fixture columns and
compare complete output bytes with the original default rows.

## Latest affected checkpoint — indexed disclosure, held preparation and composed replay

The human approved the remaining structural plan with the explicit Studio
optical-context correction. The coherent source batch now implements:

- Exact accepted-state disclosure lookup for object supports, construction
  suppressions and connector endpoints. Private copy-on-write index ownership,
  cold fallback/initial seeding, actual insertion/reentry order and durable
  refusal/rollback remain in the SDK. No canonical field or wire schema changed.
- A Session continuation milestone transfers completed immutable actor-family
  metadata while environment planning continues. Compiled/opening queue order
  is preserved. Play intercepts this local stage before Timeline admission;
  exact accepted group/epoch/observer ownership, optional demand, full-plan
  promotion and error/retirement/close withdrawal use existing owners. It does
  not grant metadata, event, required-image or draw readiness.
- Persistent preparation is charged before audio/presenter/outline/retirement
  admissions. A single complete operand prefix is retained at the exact held
  clock, source/membership owner and required/prefetch references, so the next
  frame can progress construction instead of repeatedly spending its allowance
  on discovery. Due-time selection stays live. Separate required/future surface
  coverage remains ordered; moving accounting does not make atomics hard2ms.
- Effects lends only its actual completed exact PhaseResource under the existing
  mutex/invalidate owner. Target request tokens, discovered resources,
  constructors, immutable preparation, materials/programs and native/global
  mutation/draw fences remain. This is the bounded phase case, not all of A9.
- Composed thumbnails advance one private scene-owned Timeline with existing
  replay preparation/publication. A completed plan can publish next frame
  without repeating preparation. Backward/reset/reload retain cold restoration.
  Shared replay records the same activation history cut as direct restoration.
  Nested thumbnail/Play charges are counted once against the shared allowance.
- Studio compares actual extent/camera/render/profile settings before resident
  composed-image cache hits and uses existing generation invalidation. Reused
  panes explicitly resize; changed source-depth/normal mode takes the existing
  fresh-owner path. Current request priority, source clocks, receiving, framing
  and actual postdraw output remain.

Independent source/adherence reviews are preserved in
[the implementation review](../.runtime/recovery-plan-20261021/remaining-opus-diff/review/structural-implementation-source-review-20261022.md),
[SDK source/controls](../.runtime/closing-repairs/schema16-disclosure-index/README.md),
[prefix/asset peer review](../.runtime/closing-repairs/schema16-disclosure-index/component-prefix-peer-review.md)
and [Studio source notes](../.runtime/closing-repairs/structural-studio/README.md).
There is no new framework, scheduler, renderer or source clock.

The single affected batch is complete at
[the exact source and results](../.runtime/tests/20261022T003122.459206Z-structural-recovery/summary.json).
It contains **16 passing cases / 8,660 assertions**, every process naturally
exits0, with zero script/unexpected errors. Source is7c2114d9 plus its saved
`source.diff`; installed Factory remains complete82a. The native Studio
checkpoint passes138, current composed preview control352, native positive
history modes294, actual-journal replay-prefix parity4,521, indexed fold
vectors1,253 and sensory/Journal589. The other affected source/ownership controls
also pass. Assertions are not a percentage of general completion.

The preview control proves fresh-versus-retained full-context pixels, later-cut
same Timeline/epoch, backward cold restoration, actual reused extent, and
same-recording/same-cut resident-image invalidation for extent, camera size,
material, source-depth and source-normal changes. Fireball's empty history
collections alone would not prove actual history: the separate existing logical
and native history gates above retain their positive duties.

Recorded explicit64-image four-view availability is **3,428.401ms initial /
224.126ms changed zoom / 2,686.187ms reset**. All exceed200ms. A separate dragon
preview was running throughout this functional cohort, so these are neither a
quiet comparison with the earlier3,949/206/4,089ms cohort nor ordinary Studio-open
timing. No fresh quiet gameplay route has been launched, and no Door/frame/FPS
target recovery is claimed. Authorization to close that separate application's
preview was requested; absent a reply it remains untouched.

The two affected Studio manifest entries now describe their current passing
functional receipts instead of obsolete known-red source diagnoses. Historical
failures, timing misses and other current R7 inventory remain preserved. No new
Factory/backend/asset blocker was found. Factory/engine sources stay read-only;
schema17/successor intake, wider A9/A12 costs and all human art/audio review
remain separate existing duties. The immutable `almost disaster` checkpoint is
preserved.

## Previous qualified boundary — empty demand and stable preview control

The local-closure/composed-cut batch below is now committed at **c53ab11d**.
Astra's subsequent review agrees that core restoration is implemented while
response, frame cost, composed previews and broader ownership remain unfinished.
The supplied feedback adds no justification for another renderer or new content
assignment. No full-suite, ordinary-startup, 100+ FPS or art/audio acceptance is
inferred from the affected receipts.

One additional source-confirmed omission is repaired in SpriteSources:
`prepare_actor_depth_bands([])` returns the same `true` before looking up the
environment index. The unconditional empty-input metadata lookup was introduced
in `291e092c`; there is no per-source/band mutation to skip in this case. Actual
nonempty preparation, shared allowance and owner cleanup remain unchanged.
The broader source review found the private support/layer initializer identical
to `9b73`. Its startup cost is inherited; no exclusive 13–18 ms saving is assigned to
the new empty guard. Other empty consumers still poll/retire real owners and
were not bypassed.

The existing preview timing control had two demand owners: its explicit
four-view request and TimelineView's automatic one-view callback replaced each
other's signatures and reordered the same queue. The test now pauses only that
automatic callback during this explicit measurement. Actual Play children,
source clocks, frame/postdraw waits, all 64 samples, canonical/pixel/reset duties
and the existing shared remaining allowance plus one cache poll remain. Prior
processing is restored after measurement; ordinary product scheduling is unchanged.

The two affected existing controls pass with natural exits 0 at
`.runtime/tests/20261021T235259.013386Z-recovery-empty-demand-preview`:
actor material preparation 135 checks and preview resources 280 checks. Exact
source is c53ab11d plus saved source.diff. The saved preview-resource receipt
records stable four-view availability 3,948.679 / 205.764 / 4,089.127 ms for initial,
changed zoom and reset. All remain above 200 ms. These are corrected four-view
control measurements, not proof of an ordinary UI speedup; the older receipts
with competing request owners remain intact. No new quiet gameplay timing was launched
for this bounded batch, and the preceding uneven live cohort remains current.

The broader A9 source audit is preserved at
`.runtime/recovery-plan-20261021/source-sharing-followthrough/owner-audit.md`.
All 11 available current body-material definitions use recorded bundles already
shared by Baked. A proposed raw-resource handoff between sibling spell/hit
consumers has no current positive duplicate-load witness and was stopped before
implementation or extra tests. Choice/Startup/history owner handoffs remain
unresolved at their exact source-index/reload boundaries; private job, program,
surface and clock state is not a sharable immutable Resource. Separate private
maps do not prove duplicate disk parsing. No global cache or cached-ready
shortcut was added, and broader A9 is not marked complete.

No Factory/backend/asset defect was established by these additional source
checks. Current 82a stays installed; later complete a12f delivery and its explicit
selection/intake remain separate existing work. All artwork/audio remain
unreviewed.

## Previous qualified boundary — local closures and composed cuts

The preceding recovery is committed at **9dea8d47**, after the initial
**523d5e02** checkpoint. The next source batch preserves the same installed82a
package and existing owners. Ordinary residue-free terrain shares its original
source closure only within one plan/handoff call. Residue-bearing tiles retain
the original visibility, neighbor and height path. Every tile's support/index,
removal, reinsertion and earlier-operation requirements still update normally.
This removes repeated row construction for identical ordinary terrain; it adds
no retained topology cache.

Composed thumbnails now retain the actual identical paused Timeline across its
four camera views, avoid preparing a reference quarter immediately replaced by
the requested quarter, and group explicit all-view requests by exact sample.
Different cuts still restore/install through the original path. Effects revision,
reload, source ownership, framing, readiness and actual postdraw checks remain.
The control requires a real fresh multiview witness of unchanged canonical data
and initialization epoch; previously cached images cannot satisfy that witness.

The five existing affected controls pass, with natural exits 0, at
`.runtime/tests/20261021T233131.594014Z-opus-recovery-closure-reuse`:
environment delta 368, media demand 545, media warmup 87, actual preview
resources 280 and full native Studio checkpoint 138 checks. These are bounded
functional checks, not a complete current native suite or a timing acceptance.
An external art workshop was present during this functional batch. It was no
longer running when the separate quiet cohort began.

The following three serialized actual UI routes each pass 83 checks and exit 0:
`.runtime/tests/20261021T233602.460071Z-opus-recovery-quiet`. Exact source is
9dea8d47 plus saved source.diff; producer, route, camera and installed82a match
the previous quiet cohort. Definitions and originals remain in
`closure-reuse-measurements.json` and each full profile.

| Measurement | Latest three runs | Preceding three runs |
|---|---|---|
| Door actual submit to first sampled body | 158.434 / 123.822 / 121.063 ms | 127.512 / 114.846 / 108.105 ms |
| Door environment_commit_updates | 86.103 / 36.645 / 29.881 ms | 77.902 / 85.903 / 69.565 ms |
| Door total inclusive environment metadata | 135.140 / 79.402 / 66.972 ms | 116.178 / 121.786 / 102.042 ms |
| Door character metadata | 44.661 / 36.781 / 30.192 ms | 30.626 / 32.288 / 28.255 ms |
| Door active-group media hold | 103.538 / 60.072 / 0.000 ms | 54.489 / 28.823 / 21.337 ms |
| Door active-group world hold | 75.537 / 47.154 / 47.921 ms | 47.939 / 39.428 / 32.495 ms |
| Room Move environment_commit_updates | 16.732 / 11.446 / 11.158 ms | 22.810 / 20.170 / 20.279 ms |
| Room Move active media/world holds | Both zero in all runs | Both zero in all runs |
| Maximum frame after initial readiness, whole profile | 42.992 / 36.218 / 61.647 ms | 38.074 / 43.661 / 33.846 ms |
| Maximum command-window frame | 38.332 / 36.218 / 36.379 ms | 26.935 / 31.123 / 33.846 ms |

These results are uneven. The removed repetition and two faster environment
results do not establish a uniform response or frame improvement. Door onset
and whole-profile peaks remain open; the 61.647 ms interval must not be replaced
by the smaller command-window maximum. After-ready p95 frame intervals are also
worse in this cohort: 14.364 / 14.499 / 17.222 ms versus 13.370 / 13.418 / 15.148 ms.
This is an observed deterioration, with exclusive source attribution unproved.

The saved `closure-reuse-peak-analysis.json` and companion Markdown preserve
exact peak neighbors, owners and full phase maps. The 61.647 ms interval has
7.050 ms measured Play work, zero compilation deltas and no active startup or
source-admission work. Frame intervals span trailing callbacks/render/event-loop
work and the next process callback; measured CPU phases and lagged renderer
samples cannot assign the remaining wall interval. Pre-ready peaks do contain
29–43 ms component preparation, with 17–24 ms sources and 12–18 ms persistent
work, but no exact source IDs. Neither category is tied to a specific delivered
Factory repair or a proven introducing client change. No new package is installed.

Composed-context timings are 5,377.667 / 305.882 / 5,291.241 ms for initial,
changed-zoom and reset respectively. They remain above the 200 ms target. The
retained exact-cut witness proves reuse, not closure of whole-context latency.
No speedup is claimed from the nonquiet functional timings.

The human's latest bar-only screenshot matches the existing standalone Fireball
thumbnail-resource control, which intentionally displays that timeline without
the full Studio layout. Its generic project title made that exposure ambiguous;
the test now labels itself **NDClient · Fireball thumbnail control · Timeline
only**. Full Studio already has its own explicit title. This is a test-window
label, not evidence of missing full Studio content or an old image replay.

## Previous qualified boundary — source demand and terminal ownership

Initial recovery is committed at **523d5e02**; `d5d2ff1d` remains the untouched
`almost disaster` starting checkpoint. The follow-through below adds exact rest
source demand, A11 prefix preparation, unchanged aligned sensory-column reuse,
narrow completed same-source pane Resource sharing, Astra's two task-ownership
repairs and actual baked thumbnail sampling. The historical source/receipt
sections below retain their dates and failures; this section states the latest
execution boundary. No new content assignments are included.

The four-row shutdown cohort
`.runtime/tests/20261021T231323.714699Z-opus-recovery-shutdown` passes all rows:
cookie generation 16, real native effect/source and root-exit ownership 67,
thumbnail resources 255, Studio Transport 61 checks. Every process exits naturally
with code 0. The material task was actually unfinished before quit, and the real
root-exit observer confirms task detachment and bound-cache release. This repairs
definite ownership gaps and supplies a passing current Transport receipt; it does
not identify the exact submission responsible for the four historical dumps or
prove every shutdown interleaving. Original crashes remain failed receipts.

All three final serialized current82a gameplay runs pass 83 checks and exit 0:
`.runtime/tests/20261021T231513.606290Z-opus-recovery-quiet`. Its exact source is
523d5e02 plus its saved source.diff; all original profiles and framed pipeline
clocks remain. `recovery-final-measurements.json` explicitly separates raw SSE,
consumer entry, compilation, sampled body onset and frame scopes.

| Measurement | Final three recovery runs | Previous A10 same-package cut |
|---|---|---|
| Door actual submit to first sampled body | 127.512 / 114.846 / 108.105 ms | 123.752 / 105.255 / 111.067 ms |
| Door framed SSE-ready to first sampled body | 51.014 / 53.099 / 55.654 ms | Earlier table used a different consumer-entry clock; not relabelled here |
| Door active-group media hold | 54.489 / 28.823 / 21.337 ms | 132.122 / 139.985 / 149.868 ms |
| Door active-group world hold | 47.939 / 39.428 / 32.495 ms | Not extracted in the earlier table; not assumed zero |
| Door environment_commit_updates | 77.902 / 85.903 / 69.565 ms | 63.821 / 53.060 / 67.243 ms |
| Door character metadata | 30.626 / 32.288 / 28.255 ms | 52.986 / 49.872 / 47.874 ms |
| Room Move active-group media and world holds | 0 / 0 / 0 ms each | Media 0 / 0 / 0 ms |
| Maximum frame after initial readiness, whole profile | 38.074 / 43.661 / 33.846 ms | 36.507 / 39.035 / 41.716 ms |

The final source cut contains multiple changes. It reduces later Door media
holds; it does not demonstrate a further first-body or environment-update speedup
over A10. Those costs and full-profile frame spikes remain open. Media and world
hold intervals are separate and not blindly added to inclusive worker phases.
Command-window maxima (26.935 / 31.123 / 33.846 ms) and local post-command-ready
windows are separately recorded; they are not the full after-initial-ready metric.
The exact Reducer entry timestamp is unavailable. Consumer entry precedes Journal
staging/reduction and must not be called fold start.

Each final route uploads exactly 55 unique Idle paths, about 432.5 MB estimated
GPU storage, versus 110 unique Idle+Taunt paths and about 865.1 MB before the rest
closure repair. No duplicate upload is present in either matched union. This
establishes removed unsolicited work, not its exclusive elapsed cost.

Full-context thumbnail availability remains 5,758.801 / 233.506 / 4,128.273 ms for
the actual cold, changed-zoom and reset cohorts, above the 200 ms target. The
baked source-only stepping repair does not close whole composed-context latency.

The human's new blank-window screenshot is from the live-player profiling route.
Direct script startup bypassed the normal loading scene; the harness now reuses
its existing pointer-transparent notice and draws it before the same single Play
is constructed. Readiness clocks and actual live input stay intact. One separate
current visible route passes 83 checks, exit 0, at
`.runtime/tests/20261021T232149.705970Z-opus-recovery-window`. It follows the quiet
three-run cut and is not substituted into that performance comparison. The
closing notice adds no wait and does not establish paint throughout synchronous
teardown joins; pre-SceneTree script loading is also outside that startup fence.
The screenshot alone does not establish which exposure interval it captured.

The older wall/camera screenshot was reopened from the human's earlier attachment
and mistakenly displayed without a historical label. It is not a fresh capture
or proof that the repaired wall bug returned. No wall regression was reopened
from that historical image.

## Initial source batch

All 17 production modules below are implemented and independently source-reviewed.
Runtime qualification is in progress; source completion is not a speed or pixel pass.

| Track | Actual change |
|---|---|
| A1 local environment | Residue-free local requests return before whole-mask work. Actual residue-neighbor lookup reuses decoded bytes through the existing four-entry immutable-mask owner. Full visible point enumeration is lazy and uses the same bytes. |
| A2 mutation capture | Actor/item event captures use actual writer-local changed identities. Recording-disabled reductions skip presentation snapshots and capture-only indexing; mandatory canonical validation/order/writes stay active. |
| A3 sensory ownership | Retained mask indexing follows the exact committed canonical state, forks membership before topology changes and survives transactional refusal/rollback. Existing light/hazard value projection remains. |
| A4 Library | Existing worker/generation cancellation and 24-row/2000us Tree publication algorithm restored for current rows/columns. Passive filtering remains a whole-report scan. |
| A5 parse reuse | Existing SourceCatalog parse cache reused; the dropdown explicitly avoids unused evidence/package reads. Full Library retains provenance/evidence joins and initial raw I/O. |
| A6 Journal | Packet zero reuses its first parse while preserving setup-error, supported recorded-contract, identity, cursor and exact-byte checks. |
| A7 items | Unrelated tile/object/turn changes no longer rebuild inventory/loadout membership solely because an item effect owner exists. Actor/item/sensory/audience mutations retain observation. |
| A8 preservation | Existing selection cancellation boundaries and offered-spell joins retained. No unsafe loader rollback or new scheduler introduced. |
| B world correctness | Sparse erase/reinsert order and tile removals flow through fold, transition, Compiler, Timeline, environment planning and handoff. Earlier operation source cuts retain their sources; final selector ownership drops removed tile/support paths. |
| B ownership/Studio | Hide withdraws external weapon material through the public binding setter. Mute/Solo and inspector use actual direct/derived IDs. Effects revision invalidates existing thumbnail work; Follow includes actual motion/world candidates. |

Production files: SDK reducer/audience/transitions/fold_bodies/fold_world/Journal;
presentation compiler/timeline/world/environment_media/native_items/effect_package;
Studio case_library/study_library/thumbnail_cache/timeline_view/studio.

The four previously reviewed ready harness patch families are integrated:
current media/geometry controls, Frenzy/Blood, exact source IDs, and requirement
source fallback. The condition-material preparation controls and bounded pending-
history diagnostics were reviewed and integrated too. The latter has a six-row
cap before nullable-owner early continuation. Historical equality retirements
remain unapplied; no responsibility was retired to improve a pass count.

Focused existing controls additionally cover real-constructor Journal admission
refusals, recording-on/off canonical equality, exact accepted-state rollback,
independent Python row order, and actual-terrain removal/re-entry/path retention.
No original recording was rewritten.

## Qualification and measured recovery

Initial fast receipt: `.runtime/tests/20261021T222050.889054Z` completed
198/200. The two failures were stale Library-publication and incomplete startup
control setup, independently traced and repaired without dropping assertions.
Both passed in the subsequent affected batch on unchanged production source.
The initial 200-case result and its failed process receipts are preserved.

Initial affected receipt:
`.runtime/tests/20261021T222550.160639Z-opus-recovery-affected` completed 18 rows,
9 nonpassing. Passing actual paths include the Studio checkpoint (138 checks),
preview resources (255), weapon delivery/receiver (20/5132), condition materials
(26), world-view cache and both repaired fast controls. The nonpassing rows are:

| Row | Actual current finding / disposition |
|---|---|
| timeline_readiness_checks | Two crossed-audio assertions started before actual worker-owned stream/voice readiness; reviewed control preconditions now repaired. |
| media_demand_precompute_checks | Two oracle-premise errors: CPU retirement without pressure, and mutating boot_ready on only one compared owner; reviewed control setup now repaired. |
| character_geometry_scene_checks | All three actual pixel comparisons meet the unchanged oracle (maximum RGB error 1, exact alpha). Eleven new harness premises incorrectly demanded shader overrides for defaults or unconditional CPU absence despite retained shared ownership. Existing gate corrected; no production geometry fix asserted. |
| native_spell_batch_render_checks | 1351 checks, two failures: Thaumaturgy contributes zero measured pixels; genuine ranged-Shield original unavailable. Both remain open; no replacement/waiver. |
| native_spell_library_checks | Returned before the worker-owned Library finished publication; actual-generation readiness wait repaired while retaining all three real cases and pointer/pixel/loop duties. |
| native_spell_studio_checks | Four assertions joined the wrong parent kind; eight failures expose a real derived native_material menu-routing guard-order defect. Both source routing and exact parent control corrected. |
| frenzy_render_checks | Exit 2: existing gate requires an explicit real Frenzy journal; initial invocation supplied no argument. Genuine current Library original found; native outcome remains unqualified. |
| studio_blood_partition_checks | Supplied archived OA-walk original does not meet current blood-release/overlap duty. A genuine current walk_resume original is available; its exact overlap must still satisfy the unchanged gate. |
| studio_transport_checks | 61 assertions / 0 failures followed by native process exit 5. Windows Application Error 1000/WER 1001 confirm c0000005 in ntdll.dll at the matching process/time. The process is FAILED; the causal client/source lifetime remains unproven. |

First serialized actual UI recovery cohort:
`.runtime/tests/20261021T223244.258799Z-opus-recovery-quiet`, all three runs
83 checks / 0 failures, natural exit 0. Complete original profiles and traces are
retained; extracted values are in `initial-recovery-measurements.json` there.

| Measurement | Three initial recovery runs | Prior saved regression |
|---|---|---|
| Door environment_commit_updates | 89.245 / 71.566 / 75.521 ms | 630.678 / 857.218 / 629.598 ms |
| Room Move environment_commit_updates | 24.738 / 23.359 / 24.210 ms | 581.752 / 599.219 / 599.312 ms |
| Door active-group media hold | 213.168 / 171.243 / 183.207 ms | 627.012 / 868.700 / 603.776 ms |
| Room Move active-group media hold | 0 / 0 / 0 ms | 350.546 / 353.056 / 365.354 ms |
| Door actual submit to first body animation | 186.576 / 140.438 / 130.253 ms | Prior saved 191–266 ms range |
| After-ready maximum frame | 51.865 / 40.631 / 39.893 ms | Prior saved 47–56 ms range |

These are real improvements, not complete responsiveness restoration. The prior
saved comparison used Factory 8dd; these new runs use installed complete 82a,
with the same 1600x960/camera12 route and frozen9f producer. Do not describe the
package-different comparison as an isolated same-package percentage. Initial
Door character metadata still costs 121.891 / 76.950 / 71.395 ms; the measured
source cut precedes the A10 repair below. Inclusive CPU phases are not summed.

## Second recovery source batch

A10 is implemented and source-reviewed: SourceMetadata reuses an already-owned
non-pool reader; actual regular/group pool calls retain the nested-loader safety
workaround. Selection owns one finite direct Thread per actual job, preserves
latest-request cancellation, joins completed work before publication and drains
its exact owner before cache release. Existing diagnostics and three controls
follow that same handle. No registry, new queue, source clock or unsafe loader
shortcut was introduced.

The derived-material Mute/Solo eligibility fix, exact geometry-residency control,
and three reviewed readiness/publication control migrations are integrated.
The 20 production modules were frozen for the affected cohort:
`.runtime/tests/20261021T223942.929612Z-opus-recovery-a10`: 8 cases, 5 passed,
3 nonpassing. Selection worker ownership (51), audio readiness (204), media demand
(545), geometry (106) and Studio Mute/Solo (35) pass. The source-handoff gate stops
on the removed Samples.MANIFEST harness symbol before executing; a reviewed
current-native16 migration exists, with its pre-existing legacy-manifest rejection
explicitly unresolved. Library now reaches all three cases but retains six actual
preview/pointer/timing failures. Transport again completes 61 assertions and then
exits 5; it remains failed, regardless of assertion count.

The separate selection-media gate still needs a genuine current targeting fixture;
its two found schema9 examples were rejected before launch rather than converted
into invented current data. No newer Factory package is installed.

Second serialized actual UI cohort, after A10 and the menu repair:
`.runtime/tests/20261021T224726.015873Z-opus-recovery-quiet`. All three runs pass
83 checks, with natural exit 0. The same installed 82a package, producer, scenario,
1600x960 viewport and camera12 route were retained. Extracted original-profile
values are in `a10-recovery-measurements.json` in that receipt directory.

| Measurement | Three post-A10 runs | Before A10, same package |
|---|---|---|
| Door actual submit to first body animation | 123.752 / 105.255 / 111.067 ms | 186.576 / 140.438 / 130.253 ms |
| Door environment_commit_updates | 63.821 / 53.060 / 67.243 ms | 89.245 / 71.566 / 75.521 ms |
| Door character metadata | 52.986 / 49.872 / 47.874 ms | 121.891 / 76.950 / 71.395 ms |
| Door active-group media hold | 132.122 / 139.985 / 149.868 ms | 213.168 / 171.243 / 183.207 ms |
| Room Move environment_commit_updates | 19.620 / 23.388 / 19.180 ms | 24.738 / 23.359 / 24.210 ms |
| Room Move active-group media hold | 0 / 0 / 0 ms | 0 / 0 / 0 ms |
| After-ready maximum frame | 36.507 / 39.035 / 41.716 ms | 51.865 / 40.631 / 39.893 ms |

Door canonical-consumer entry to first body is 58.853 / 48.938 / 49.269 ms. This starts at
canonical_consumer.started_us, before staging/reduction and after SSE admission,
not at exact reducer entry or raw network receive; submit-to-consumer-entry is
64.899 / 56.317 / 61.798 ms. Do not conflate this boundary with historical
packet-receipt measurements. Inclusive CPU phases are not additive.

The remaining Door hold and maximum frame costs are not restored to the target.
These receipts qualify this route, not every native/Studio consumer. The confirmed
Windows transport access violation lands within ntdll!RtlEnterCriticalSection;
without a stack or lock address, the responsible source owner remains unknown.
Exact OS evidence is preserved under
`.runtime/closing-repairs/studio-transport-native-exit-20261022/`.

## Retained-history and exact source-demand follow-through

The initial 20-module recovery, reviewed harness migrations and corrected plan
are checkpointed as **523d5e02**, `Restore Opus fast paths and current ownership
contracts`. The original `d5d2ff1d` checkpoint is unchanged. Generated reports
remain separately preserved, not silently promoted to whole-suite acceptance.

A11 is now applied in native_inputs/native_spell_renderer. Actual nonbirth
sampling declares prefix demand; existing preparation realizes whole immutable
requests under its remaining allowance. Actual birth sampling still skips
predecessors. Endpoint withdrawal, original source/material/clock snapshots,
exact requested/drawn identities, retained epoch and sample readiness remain.
Prefix status does not introduce a Timeline media-ready gate. One original
Factory capture request remains indivisible; no hard 2ms bound is claimed.

Grouped existing-family receipt:
`.runtime/tests/20261021T225906.979773Z-opus-recovery-history` passes all four rows:
actor_history_capture 350, material_transition 194, native_history_modes 294,
native_material_transition 16,432 checks; all process exits 0. Both seats, actual
history/departure/current-copy paths, all quarters, seek/removal, canonical
immutability and native pixels are covered by their original controls. This
functional receipt does not establish improved frame cost or every birth/
withdrawal scheduling interleaving.

Further Door attribution separates first-body onset from later active-group
holds. In the three post-A10 profiles, all 132–150 ms of media hold occur after
continuation metadata is ready; source decode/upload/publication alone remains
pending. The 110 actor uploads are unique: 55 Idle paths plus 55 unsolicited
Taunt paths. Their cumulative parallel decoder times are not elapsed hold times.
The migration added unconditional equipment-clip demand to every living actor's
rest closure, absent from Opus. This is independent of real equipment tracks.

The reviewed restoration removes that blanket addition in media_warmup and
restores two existing rest-only oracle lists to Idle. Actual compiled equipment
tracks retain their own Taunt first-use, outfit witnesses and body scheduling.
No decode budget, source clock, residency policy or readiness barrier changes.
The exact saved analysis remains in
`.runtime/recovery-plan-20261021/door-residual-analysis-20261022.md`.

A bounded Library control correction is also applied: it observes the actual
atomic production Out-to-In publication, independent original canonical prefixes
and actual postdraw host, instead of inferring a boundary from external frame
sampling. Follow-on manual seek still must keep an active recorded track visible
and retain exact selection. Exact requested-row pixel/gutter inspection uses the
existing explicit manual Follow control. Reset may retain only released empty,
disabled spares; close must delete them. All pixel/pointer/loop/close duties
remain, with no widened thresholds or deadlines. No product navigation defect
has been established from the prior six failures.

The existing media/first-use/equipment/Library cohort completes at
`.runtime/tests/20261021T230257.818099Z-opus-recovery-rest-demand`: all four rows
pass, with 87 / 657 / 1281 / 159 checks and natural exits 0. The Library control
covers all three actual recorded cases. Post-rest-demand quiet timing is not yet
available. The prior failed receipts remain failed; this passing Library result
does not explain the separate native transport access violation.

## Unchanged sensory columns, safe pane reuse and shutdown repairs

A3's explicitly deferred aligned-value work is now reduced within the existing
retained context. Only an exact already-indexed accepted mask, unchanged topology
and empty validated selected changes may borrow the prior aligned light/hazard
column. Cold, changed and mismatched-mask paths keep the original codec and its
malformed-prior boundary. Shared alignment indices are constructed lazily only
when a column rewrite needs them. No arbitrary mutated/forged prior context is
promoted to an accepted canonical cut.

A9 now recovers completed-path sharing for the existing same-source ReplayPanes
relationship. A genuinely new pane may borrow only joined immutable res://
Resource entries from the actual reference native renderer. Jobs, errors, private
occurrences, program/readiness state and clock state remain private. The existing
same-index/bundle and explicit reload refusal remain; these are not invented
backend-commit or approach-revision qualification checks. Normal global
compiler/source/postdraw fences still gate construction. No global cached-as-
ready shortcut or new registry is introduced. This bounded restoration does not
prove repeated disk parsing or close every cross-owner A9 opportunity.

The current source-family receipt
`.runtime/tests/20261021T230850.303577Z-opus-recovery-shared-ownership` passes all
four rows: exact sensory Journal ownership/rollback 537, independent fold vectors
901, immutable preparation 35, and native Studio checkpoint 138 checks. All
natural process exits are 0. It does not qualify all current consumers.

The human subsequently supplied Astra's four-dump shutdown analysis and two
reviewed patches, now applied at the clean source boundary. Actual saved dump
candidates and binary/source corroboration identify a pool Task/Callable releasing
script-bearing data after language destruction, not the exact historical task.
Two definite client ownership omissions are repaired: final process-root join of
the exact prototype-material task, and terminal Lighting2D release of its range-
cookie tasks through existing LightCookies.release. Ordinary page replacement
still retains reusable cookies and subclass effect-cookie cleanup remains.

Recorded source-only thumbnails now select their actual baked absolute sample
directly. Live source stepping and actual final postdraw admission stay unchanged.
Both patches remain unqualified by the preceding passing source cut. The next
grouped source/thumbnail/transport cohort must preserve actual native exit status;
a real unpolled material task exercises the process-root collection boundary.
See [the current crash investigation](STUDIO_NATIVE_EXIT_2026-10-21.md) for the
four original dumps, introducing ownership gaps and precise causal limitations.
The earlier narrow WER archive search did not find those separately saved dumps;
its lack of a local archive stack must not be repeated as a claim that no saved
dump exists anywhere.

A12's source review found immutable capture reuse, real draw acknowledgement and
suspension already delivered and consumed. A tight crop needs a complete camera,
UV, numeric-depth, receiver and live-body coverage contract. Changing size alone
is unsafe. A source-owned one-shot clear of the otherwise blank departure
protection pass is an optional follow-through candidate, not an invented missing
required Factory/backend API or a quantified saving. No source package is changed.

## Remaining recovery work

A9 and A12 remain follow-through: safe completed-resource sharing and actual
capture-region/continuous-view cost. A10 and A11 are applied with the bounded
qualification above. Current safe loader/drain/draw ownership is retained while
complete adaptations are derived. These are not qualified by the initial
17-module batch, nor is every current native/Studio path complete. No newer Factory package is being
installed ahead of recovery.

No new Factory/backend/asset defect is established by this source batch. Existing
external ledgers remain authoritative; delivered work is not re-requested.
All artwork and audio remain unreviewed by the human.
