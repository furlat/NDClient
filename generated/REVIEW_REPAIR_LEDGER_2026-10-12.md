# Open-review repair acceptance ledger — 12 October 2026

## Received-event preparation acceptance — 12 October, final native runs

Asset families from the displayed and received upcoming groups now preload through
the existing loader. Private workers prepare world rows, floor buffers, finite
wall targets and exact static order; hidden native construction is sliced and
published only at the matching causal boundary. Startup readiness uses incremental
source accounting, including an in-flight fixture-role promotion regression fix.

Latest evidence: [validation and explicit limits](async_preparation_validation.json),
[whole-frame profiles](async_preparation_profiles.json). Both complete recorded
runs reach the canonical terminal state with no presentation/runtime errors and
no discarded profile frames. Gallery ends with 1,761 tiles and 360 objects after
all 122 groups, including authentic cached-view invalidation.

Gallery traversal intervals above 33.333 ms fell from 51 to 20 and the maximum
from 59.405 to 45.139 ms. Post-startup p95 is 3.816 ms; whole traversal including
preload has p95 3.318 ms. Startup finishes at 15.019 seconds in Gallery and 14.083
seconds in Crypt. Crypt has no interval above 33.333 ms. Counts/sample trajectories
differ because loading and idle queue gaps differ; these are recorded-route
comparisons with VSync off and unflushed OS caches, not hardware-independent bounds.

Causal lookahead checks pass 8,677/0; passive wall preparation 2,295/0; media and
encounter checks 64/0 and 57/0; actual in-flight role race 10/0. Native publication
has 119/125 passing: six strict captures each differ by one byte at one pixel under
native direct lighting. All nine fixed-direct image counterparts and all other
125 control checks pass exactly. The strict assertion was not relaxed; the
light-dependent byte discrepancy remains open. Both lanes pass state, ordering,
picking, floor representative, pending rotation, reset and ownership checks.

Remaining performance work is explicit: new-family media selection reaches about
24–29 ms; final native scene/style/mask/HUD publication and cached-view retirement
still contribute stalls. The current image check limit and performance tails are
not closed by these changes. Character-lighting artistic evaluation remains in
the user-directed separate project. Local unconfirmed command prediction remains
a subsequent presentation feature, with no two-frame correction guarantee.


Scope: current user authorization to fix the open client review problems. The user subsequently assigned the isolated single-light reference demo to a separate task; it is no longer a delivery requirement here. This ledger tracks acceptance; it is not a validation result or a new architecture plan. Runtime/backend/art changes are owned by the assigned implementers. This reviewer makes no native/GPU runs.

## Latest measured status

The source-frozen runs in `order_native_profiles.json` completed with clean logs, full canonical agreement and drained recordings. Crypt playback measured 8,271 frames, 2.885 ms p95, 25.209 ms maximum and no frame above 33.333 ms. The authentic Gallery completed 102 packets, 122 groups, 1,761 disclosed tiles and 360 objects; its remaining frame stalls are **not fixed**.

| Gallery traversal checkpoint | Frames | p95 ms | Maximum ms | Frames above 33.333 ms |
| --- | ---: | ---: | ---: | ---: |
| Windows-source A/B baseline | 25,168 | 3.566 | 72.946 | 78 |
| Sparse world update | 25,299 | 3.850 | 62.459 | 48 |
| Complete static-order cache | 25,057 | 4.050 | 59.405 | 51 |

The final sort cache did not universally reduce latency: the maximum decreased, but p95 and the count of slow frames increased versus the sparse checkpoint. At sequence 40, player CPU still reached 50.376 ms, including world 26.155 ms, scenery 4.278 ms and walls 16.467 ms; static ordering was 6.669 ms within the wall work. Sequences 77 and 98 still had 43.890/43.005 ms frame maxima and 33.449/35.033 ms player CPU. Their static-order costs were 7.070/7.298 ms. Membership-driven order rebuilds remain material. Nested phase timings overlap and must not be added as independent totals.

Gallery retirement-active intervals totalled 858.775 ms. This is not a measured camera-request delay; request-to-publication while the large Gallery backlog is pending remains unmeasured. The smaller Crypt fixture's 170.996 ms request-to-publication result does not bound that case. The strict native-direct wall-member comparison also retains one q2 red-channel difference of 1/255; its fixed-direct control passes. There is no blanket correctness or performance closure claim.

The complete-order implementation retains the seven-field-plus-ID comparator, clears its full cache on view deactivation, invalidates immutable placement/representative changes, and includes node position in the native offset guard. Latest focused world-incremental checks pass 95/0 after that guard; the preceding integrated batch below remains recorded at 93/0. These checks establish their named behavior, not that all lag is removed. No reviewer runtime edits or native/heavy test runs were made.

## Source-location A/B and follow-up checkpoints

The user required a matched asset-location comparison before further renderer algorithm changes. Copying and file validation completed before either run; both used the same frozen code, recording, render settings and completion gates, changing only authoring/media roots. The originals were preserved. Source loading, decode and media holds remain separate from synchronous world updates and later native cleanup frames. OS caches were not flushed, so the comparison does not establish an operating-system-cold result.

The incremental native-view teardown patch was identical in both comparison arms and was separately native-validated. Its acceptance includes request-to-view-publication delay after cached-view invalidation, because draining a bounded disposal queue before preparing a new quarter can reduce frame stalls while adding a visible camera wait. Earlier profiles alone did not validate this new patch or close the 70.775 ms traversal and 86.998 ms invalidation findings below.

Comparison review: copy verification reports 134,380 matching relative paths and sizes, with no missing, extra or size-mismatched files. The runner now requires the current child's `PROFILE_SAVED` output rather than accepting an older matching report. Gallery traversal remains active through the native retirement backlog and two subsequent frames; the camera fixture measures request-to-publication from before `request_view`. Character geometry remains on its existing Windows path in both arms. The separate user lighting demo remains running, which the A/B report explicitly discloses; these runs are not isolated GPU benchmarks.

Saved retirement fixture: 71 checks, zero failures; 298 native nodes retired, 25 preparation frames, request-to-publication 170.996 ms, maximum preparation/publication callback 5.397 ms. This validates that Crypt case, not the larger Gallery backlog. All four source-location runs now report clean logs, full canonical agreement and drained recordings in `windows_source_comparison.json`. Total displayed time and advanced-step counts differ: the timeline advances an idle displayed clock when its bounded queue is empty while the next recorded operation is prepared. Therefore the runs replay the same authoritative commands/states but do not produce identical source-time sample trajectories. Compare matching sequence/world contexts and loading holds separately; successful completion alone does not close the remaining world/native-frame costs.

Observed A/B outcome: Gallery had 78 frames over 33 ms in each arm, with maxima 66.122 ms on WSL sources and 72.946 ms on Windows sources. The same sequence 40 world update remained expensive: world CPU 32–36 ms, scenery 7–8 ms and walls about 15 ms. Media-held intervals totalled about 19.7 seconds versus 17.6 seconds, respectively; this is not isolated disk attribution. Native Windows roots remain selected. The result does not explain away the renderer stalls. Work now resumes on accumulated dirty IDs, ordered incremental world/scenery projections, primitive floor-sort indices and measured wall/order work. Acceptance must preserve staged-to-canonical support transitions, actor-only negative-height batching changes, media-blocked accumulation, and canonical insertion order after remove/re-add before one render consume.

Bounded sort follow-up: primitive-index sorting retains the exact original `Placement.project(...).y` value, native Y-only comparator and input order, including its equal-Y permutation. Owner reports Gallery ordered-array checks 308/0, native floor-update checks 168/0 and visibility checks 24/0, including remove/re-add and exact original-source pixels. This closes that ordering regression obligation, not whole-frame performance. Incremental world/scenery changes and their ordinary (non-forced) visibility handoff still require their own acceptance before final profiles.

Wall delta review found an active/prepared support mismatch: prepared quarters used admitted presentation tiles while active qualification used canonical tiles alone. The saved fix uses the same presentation overlay in both paths. The sparse qualification suite now reports 120/0, including staged admission, canonical adoption and staged removal in all four quarters. Pending tile changes accumulate independently for inactive quarters until each consumes them; bucket revisions invalidate affected candidates. This preserves the existing finite-boundary/member policy. Original native member/visibility suites and changed-world performance profiles remain independent gates.

Sparse world review: actual source-prefix/staging oracle 1,238/0 and real Compiler→Timeline checks 1,218/0 cover 102 packets, 122 groups and 299 sampled staging/commit boundaries. Dirty identities survive multiple advances and media holds; reset/revision mismatch forces a full refresh. Ordered remove/re-add and an ordinary, non-forced same-current-ID floor material transfer pass. The measured 7,245 projected dirty records versus 377,612 records in a full scan is a work-count comparison, not a frame-time result. Read-only source review found no further material defect in the saved consume/visibility path; integrated native checks and profiles are still required.

Latest integrated native checkpoint (`sparse_native_acceptance.json`): world incremental 93/0, view cache 123/0, rotation 74/0, wall visibility 358/0 and compositing 27/0, with clean logs. The consume boundary now updates the scene's world revision itself, and named door-rendering fixtures await real source preparation without queuing and discarding an unprepared operation. The strict native-direct member test still has its documented one-pixel q2 red-channel difference of 1/255 (73 checks, one failure); its fixed-direct diagnostic remains 73/0. This is not an all-pixels-passed result. The subsequent Crypt/Gallery profiles are reported at the top; no performance closure is inferred from these correctness passes.

That profile completed the authentic Gallery canonically over 25,299 frames, with 48 frames above 33 ms and a 62.459 ms maximum, versus 78 and 72.946 ms in the earlier Windows-source arm. The subsequent complete-static-order cache and its measured limits are recorded in the latest-status section above.

## Accepted before this pass

- Native `WorldEnvironment` white ambient energy 0.18: actual Crypt comparison 13/0 and emitter checks 43/0; isolated zero-ambient control retained. Production point lights were still custom at that checkpoint.
- Geometry-companion CPU residency: media 59/0, actual scene 10/0; accepted cached plans retain exact CPU/GPU roles, original alpha picking remains. Four actual companions released 19,660,800 decoded Image bytes once; this is not measured RSS/VRAM or frame-time savings.
- Prior wall member/colour/geometry/history fixes remain regression obligations. Historical floor-diamond acceptance is superseded, not revived.

## Obligation history

The table retains earlier checkpoints and their evidence. Later checkpoints above and the root's final validation index supersede older pending statuses; this table is not a claim that every earlier pending check remains unrun.

| Area / owner | Finite acceptance | Current disposition |
| --- | --- | --- |
| Native item lights / root | One native source per disclosed active item; original NORMAL/LIGHT_VERTEX and tint/alpha retained; no duplicate custom torch contribution; source retirement/activation, pause/flame clock, raised support/jump, architectural two-sided convention. | Saved implementation reviewed: native Omni nodes, immediate retirement visibility, original receivers and no production custom torch loop. Native migration suite and actual scene/profile acceptance pending. |
| Native-light migration bounds / root | More than eight relevant sources on the shared floor; original floor-skirt painter output; source-reconstructed receivers near unmodified quad bounds; actual Crypt and furnished gallery. Optical sphere falloff must not be called backend circular range equivalence. | Saved affine packet-extrema environment AABBs, relative-source-camera modular AABBs, water plane bounds and ground union reviewed. Settings request 64 lights/object and 256 visible, also hardware-limited. Native shared-floor coverage is being checked separately. Displaced-receiver native fixture now passes 17/0: all four quarters receive light (0.67451), the original quad-only AABB control stays black, and restoring expanded bounds restores exact pixels. The fixture is explicitly a synthetic admitted depth extremum; its initial zero samples came from independent light-camera frustum culling, corrected in the test camera without production changes. |
| Water / map_audit | Original authored graph remains; native receiving replaces unintended unshaded output; explicit displayed clock freezes under pause/media hold and replays deterministically. Cover live and maintained offline path. | Live/native receiving and displayed clock source reviewed; saved native report 11/0 covers point/directional, pause/media waits and replay. Older compiled grid preview explicitly retains its offline engine-time/emissive reference convention and is excluded from live-player migration claims. |
| Replay preparation / render_audit | Bounded lookahead independent of durable journal/ACK; paused and media-blocked display does not block transport; full-buffer cancellation wakes and exits; resume/reconnect produces every original group exactly once. Close latency may include one active atomic decode/compile. | Saved separate worker reviewed. Owner reports session 28/0, authentic Gallery 102 packets/122 groups and independent Journal canonical parity, active cancellation 230 ms. Bound is two complete operations, not a byte/group cap. Actual Crypt delayed-command proof now 14/0: 2,000 ms forwarding delay, 309 process frames, 196 native animation samples, camera wheel response, 7.377 ms frame p95 / 9.686 ms max during the wait. This demonstrates client responsiveness during that wait, not reduced backend processing cost. |
| Admission / render_audit | Single strict internal admission where already owned; public journal remains strict; identity, audience/epoch, file/cursor, conflicting duplicate and reducer-failure atomicity remain on every replay/disk route. Current SDK differential and authentic prefix checks retained. | Earlier replay identity/scope bypass fixed. Saved disk and internal-admission paths reviewed; wrong-identity/wrong-audience regression included in session suite. Final execution index reports full SDK 11,733 clean, including completed-body immediate-close success and truncated-close rejection. The saved native delayed run used graceful close; subsequent actual headless Crypt acceptance uses the repaired immediate-close transport. |
| Full-recording validation / render_audit + root | Completion requires displayed sequence equals actual available final sequence, drained queue/current, no errors, canonical parity. A source-indexed terminal flag or short prepared prefix is insufficient. Initial-only fixtures explicitly say so. | Old early-close and prefix-only profiler gates corrected. Saved player-view discovers motion probes as bounded windows arrive; profile gates require latest source cursor plus terminal. Native bounded-session late-lethal player-view 47/0 and history 45/0 now report complete canonical drain. The ranged history fixture is being corrected to require actual witnessed body components without demanding a wholly green event when every recorded event has additional missing authored requirements. Final native profile/harness results remain pending. |
| Diagnostic retention / render_audit + root | Bounded completed/skipped diagnostic history with lifetime totals; bounded or streamed explicit FrameProfile recording and honest truncation/termination metadata; journal durability is not capped or discarded. | Saved timeline rings retain 2,000 rows with lifetime totals; explicit FrameProfile retains 60,000 samples and exports total/evicted/capacity. Session and runtime-retention checks exercise eviction. Summaries describe retained samples, not evicted full-run history. |
| Metadata enumeration / render_audit | Incremental paths equal exhaustive current/upcoming path sets over actual gallery and changed state/fixtures/corner neighbors; measured worker work decreases; no future visuals admitted. | Saved one-map incremental index reviewed. Owner reports 371/0 over all 102 Gallery packets / 123 current-next windows: exact path/fixture equality, 7,650 to 1,464 ms metadata CPU only. Raw immutable source JSON handoff avoids a second scene-thread read; derived indexes stay worker-owned. Media suite 62/0 reported clean. |
| Below-floor order / map_audit | Native four-view overlap/picking fixture for negative actor/support behind higher floor; staged and remembered supports included appropriately; batch eligibility restores without stale cached views. | Saved ground-background eligibility and cache invalidation reviewed. Native scenery 36/0 covers all four views with 740–1,423 overlapping source pixels per view, zero wrong pixels/picks, and restored batching. The source-over oracle preserves authored fractional-alpha edges; captured lower actor/floor overlap independently inspected. |
| Remembered scenery / map_audit | Visible → remembered → visible distinction from subjective grants; preserve last-known values, source alpha and current actors/emitters/contents privacy. Mixed current/remembered corners must not silently promote remembered members. | Saved subjective-grant mapping, mixed-style native wall members, ground instance custom data and source-alpha-preserving shader reviewed. Pure state 32/0 plus native scenery 36/0: sight-only styling changes original floor pixels while retaining node identity; visible/remembered captures independently inspected. Root additionally reports 24 exact native floor pixel equivalences (four views × current/remembered/mixed) after setting both instance custom data and explicit white instance colour; custom-data COLOR defaults were caught visually. This does not simulate hidden current values or optical wall shadows. |
| Creation/camera spikes / root + map_audit | Same small and gallery recordings; cold reveal, first/warm quarters, wall modes, exact final state and no errors. Preserve current view during staged build and reject stale revisions; report max/p95 and loading holds separately. | Latest valid profile reported: startup 4.9 ms vs 128 ms, small playback maximum 23.8 ms; Gallery first-quarter 128–134 ms and repeat 43–48.6 ms remain open. Owner is preparing one explicit hidden target view with atomic publication, stale-target invalidation and unchanged-world cache reuse. Saved native camera evidence now reports world-view cache 123/0 and atomic preparation 41/0 on actual Crypt sources, including exact fresh-source pixels, advancing old-view clocks, cached cancellation, visibility/projection/elevation changes and stale-generation retirement. Crypt preparation/publication maximum was 5.187 ms; that does not certify the much larger Gallery. Full Gallery frame profiles remain required before another performance claim. A later strict native-direct Hidden q2 comparison remains failed at one red pixel by exactly 1/255 (three restoration cases at the same pixel); the earlier saved cache pass does not supersede it. The paired fixed-direct diagnostic passes 73/0 exactly, including translucent four-view output, and unchanged solid repeats are exact in both. This localizes the difference to the native-direct path without proving its precise cause; the native-default strict assertion remains unchanged. The final Gallery after-profile confirms a remaining changed-world blocker: traversal maximum 80.585 ms, with world 34.863 ms (including ground 13.308 and rows 11.039), walls 20.25 ms and scenery 8.337 ms. Those nested phases must not be added as independent totals. Cold rotation now measures about 14–16 ms versus about 130 ms; this does not close disclosure spikes. The owner is pursuing bounded repeated-work/cache and delta updates while retaining exact current/staged/remembered output and atomic world/order/mask publication. The next Gallery profile additionally fills all quarters at authentic sequence ≥75, resumes the same recording, and measures the first actual source-generation invalidation through two following native frames. This is a new scenario, not a matched-baseline speedup claim. Review found an equal-total-count object-removal/tile-admission boundary-index invalidation edge; the saved fix tracks object IDs independently, with a specific cached/uncached equivalence case. Source review found no further blocker in the retained native floor buffer, sparse current-visibility set or original projection cache. Final focused results reported: actual Gallery cache 1,238/0 (102 packets/122 staged lineages), retained floor 120/0 (20 native cases, exact pixels), floor visibility 24/0, scenery 36/0, incremental 93/0, view cache 123/0, rotation 42/0, compositor 27/0. Same-state member comparison still retains the explicit q2 native-direct one-byte pixel discrepancy; fixed-direct 73/0 is a diagnostic, not its replacement. The subsequent full Gallery gate failed: traversal still reached 70.775 ms (world rows 11.192 ms, ground 10.971 ms, scenery 12.079 ms, walls 17.871 ms). The new authentic cached-view scenario exposed an 86.998 ms native frame after invalidation while player work was 2.565 ms. These are separate open costs; focused correctness passes do not establish completion. Owners are measuring changed-source cardinality and native view-resource lifetime before another repair. A separate no-renderer/no-media Gallery diagnostic isolates passive compiled-message destruction: maximum 43.254 ms; at sequence 99→100, release was 35.718 ms while acceptance/advance were 0.037/0.326 ms. A reviewed optional Timeline→Session handoff stages completed groups until the next poll, then releases their pure data on the existing preparation worker outside its mutex. This is neither GPU texture work nor backend latency; Updated session retirement checks now report 31/0, including all 122 actual Gallery groups drained at close and no pending retirement references. Later native acceptance reports corrected immediate-close delayed Crypt 15/0 with close 1 ms and completed groups drained; the separate demo was running, so wait timing is responsiveness evidence rather than an isolated performance benchmark. Full Gallery after-profiles expose a separate changed-world stall below. |
| Retired actor hosts / root | Release no-longer-required scene nodes/animation hosts; recreate exact authored state if redisclosed; active/staged/current-track actors retained; canonical remembered actors remain data. | Saved immediate hide/free plus passive last-facing retention reviewed. Scene-owned shared immutable animation templates replace an initially identified process-cache leak; runtime-retention 10/0 reports independent clocks and held-death recreation. Actual Crypt actor lifetime fixture 7/0 confirms native nodes free, canonical actor remains, and Idle redisclosure restores NE plus exact source time. |
| First-use icons / root | Measure opening actual large action/inventory UI. If material stall is confirmed, remove synchronous first-use work while preserving exact icon identities/input readiness. | Measured original first inventory open: 51.273 ms for 13 disclosed items. Saved worker decode plus stable per-source native ImageTexture update reviewed; one main-thread upload/poll, active input and original identity retained. Recorded UI 103/0 and portrait decode checks reported, including stable ImageTexture identity through asynchronous completion and 33 exact original image byte comparisons; root independently inspected the aligned, readable native screenshot. Upload polling is included in measured hud_process. A subsequent bounded descriptor lookup optimization preserves short/exact/qualified ContentRef semantics; root reports UI 104/0 with all 471 admitted references compared and inventory-open CPU 5.963 ms. Native grid-cache 29/0 preserves original projected corners and output order across geometry/view changes. Final renderer profile still remains separate. |
| Defensive shader guards / root | No numeric access outside has_geometry/valid region, including normal region; keep original unsupported colour fallback. | Saved geometry and normal bounds guards reviewed. Original unsupported colour fallback preserved; native regression suite pending. |
| Native ownership recommendations / root | Explicit disposition for shared sprite helpers, immutable rig AnimationLibrary reuse and stable native scene/UI layout; retain proven causal timeline and native Controls. | Shared immutable libraries implemented with per-host playback and scene-owned templates. Retain tested sprite-helper inheritance and native Controls: maintenance recommendations alone do not justify broad controller/UI rewrites; no required correctness blocker found there. |
| Single-light demo | User explicitly reassigned demo delivery to a separate task. | Removed from this task's outstanding work. No cross-task communication or shared production edits are authorized by this ledger. |

## Boundaries and nonclaims

- Source float-field discontinuities are diagnosed asset-quality limits; a client repair must not fabricate replacement geometry or claim complete physical calibration.
- Transparent optical receivers are not opaque walls. Native Omni does not itself supply real optical wall shadows, SSAO or physical depth composition.
- Native atmospheric fog, ambient illumination and subjective remembered-map styling are separate responsibilities.
- The continuous translucent owner pass is a measured-cost concern, not proof that UPDATE_ONCE is correct. Any change must reproduce first-frame, quarter, fractional-zoom and overlap acceptance; previous failed experiments remain evidence.
- Soft media budgets are not VRAM caps. CPU byte accounting, static/VRAM monitors and process RSS are separate measures.
- No old Unity/demo speedup or pre-geometry benchmark substitutes for the current live-player measurements.

## Local prediction and media selection — accepted finite scope

The player now starts an authored body/motion prefix after native preview approval
and command submission. Full game/epoch/audience/command identity survives every
compiler group and session message. Prediction shares the confirmed track sampler
and native AnimationTree, leaves reducer/disclosure/log/trace state unchanged,
reconciles only at authoritative admission, and relinquishes before reactions.
Unconfirmed progress is bounded to 120 ms before entry/contact. Explicit rejection
returns over 80 ms; ambiguous receipts retain their original unresolved command.

Review caught and fixed attack-source selection using item category instead of the
backend's equipped-source enum. Adapter checks compare possible outcome variants,
source rates, hidden slots, contact bounds and immutable authoring. Unsupported or
ambiguous prefixes remain confirmed-only; future effect channels require authored
samplers. Character-light integration, studio and VFX migration remain subsequent.

Accepted evidence: identity 769 checks; prediction/adapter 3,079; full Gallery
source-clock regression 7,969; eight short movement/attack/OA regressions 670;
canceled-node regression 302; actual delayed-server native scene 32; encounter
media 79, media lifecycle 64 and in-flight role race 10. All pass. Native live
checks include two-second command delay, body continuity, camera rotation,
walking/jumping and cold journal agreement. Full Gallery native profile drains
all 122 groups with 1,761 tiles/360 objects and exact canonical state.

Media source selection updates only new/removed/role-changed paths and uses the
worker's family estimate summary when all known sources fit. CPU-only family
selection median: 16.188 → 4.548 ms. Native media-planning maximum: 29.112 →
11.553 ms. Full traversal frames over 33.333 ms: 20 → 16; maximum: 45.139 →
46.233 ms. Post-preload p95: 3.816 → 4.475 ms. This is a mixed whole-frame result,
not closure of all spikes. Wall/world/scenery/HUD publication and native view
retirement remain measured costs. Idle prediction p95 is 0.019 ms. Old one-byte
native-direct comparison deviations are not claimed repaired by this work.

Index: [prediction_validation.json](prediction_validation.json).
Raw comparison: [prediction_profiles.json](prediction_profiles.json).
The runtime was frozen before the final native Gallery run. All owned acceptance
processes have exited; the separate user lighting process was left untouched.
