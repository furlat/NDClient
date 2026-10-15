# Native spells in the client and Studio

> **15 October review checkpoint:** incremental optimization is paused. The next
> design is [Preparation, publication and ownership](PREPARATION_PUBLICATION_OWNERSHIP_PLAN_2026-10-15.md).
> That plan supersedes the performance continuation below, while preserving this
> document's event semantics, approved graphics and artistic deferrals.

## Current continuation — live gameplay feedback

Latest actual-player continuation (20:35 UTC), `.runtime/player-runs/20261015T203539.824901Z`:
81 checks passed, zero trace drops and zero media/native/world holds after either
Fireball starts. Complete-packet-to-first-animation is70.236 /64.223 ms; whole-action
maximum frames32.600 /29.158 ms (prior20:23 run34.233 /40.204 ms). Server execution
is542.618 /396.777 ms, measured separately. The <30 ms response and no-spikes
objectives remain unmet. Other applications remain on the GPU; aggregate changes
are not isolated attribution. Default runtime, graphics and authored timing stay
unchanged. Owned probes exit; no user preview/application was interrupted.

The impact trace proved representative terrain row IDs could change while their
actual mesh node stayed identical. NativeSceneSupport now keys its existing floor
map by that node identity, both in hidden preparation and displayed sync. At the
measured impact the old1.881 ms retirement is now0 ms, with zero created/retired
helpers and the same source node. Original painted-output/depth comparisons pass
12,121 checks across four views/two zooms, row/contact change, actual node replacement,
visibility, disable/wake and output cleanup. Feedback review finds no blocker.

Worker demand supersets now require exact prior scene/epoch/family/roles/header
proofs and the combined optional+required budget cap. Exact current roles/readiness
refresh immediately; the existing worker refills optional selection. The subsequent
typed-header change allows proven contractions whose metadata has raw dimensions
and explicit CPU/GPU ownership; unknown/residency-dependent inputs still fall back.
1,342 oracle/worker checks and119 actual-PNG race checks pass;27 recorded comparisons
show5.810→4.029 ms. Live719→603 contraction now defers selection in6.007 ms rather
than repeating the old11.5 ms full selection. Admission still has an11.058 ms demand,
and a new-family superset guard takes3.388 ms. Motion owns further measured demand
work; feedback independently reviews budget/readiness, anti-slop and anti-OOP.

Actor diagnostics show impact binding1.387 ms and outfit checks0.626 ms across55
layers. Interaction investigates whether material keys deep-copy/compare unused
flash and body-surface provenance, and whether one per-actor shader operand payload
can remove repeated per-layer derivation while preserving exact uniforms/pixels.
Root owns sequential live measurements and overall plan adherence. The proposed
shadow parameter delta was pixel-identical but negligible and reverted; a bulk
blood upload matched10,656 actual native buffer checks but saved only~0.006 ms/sample
and was rejected. No new framework or artistic change is justified by those probes.

The atlas diagnostics proved58 actor preparations accepted, with zero proof
misses;47 outputs were nevertheless allocated again because extending an aliased
source directory was incorrectly treated as extending the separate prepared-output
directory. The two membership guards now consult actual output membership. The
combined actor-preparation/static-prefix/dynamic-extra regression passes1708 native
and56 sparse checks, including exact first-draw pixels and no replacement allocation.
The previous idle-version explanation was not the measured cause.

Particle construction qualification: only already-prepared resources whose child
resources were audited as constant may keep those children when making a private
ParticleProcessMaterial shell. Raw sources, scripted materials and mutable child
resources retain full duplication. Built-in property names are derived once;
64 ownership/mode cases and518 actual Fireball source/clock/peer/donor checks pass.
Alternating fire/smoke constructor medians2.910->2.178 /2.977->2.257 ms; scan medians
1.411->0.718 /1.403->0.709 ms. A full per-emitter guard scan was slower and rejected.
These are isolated measurements; combined live qualification remains pending.

Corrected optional-demand comparison uses the actual lowercase reference normal
profile:589->452 paths, not the earlier capitalized-profile547->410 fixture.
Fourteen exact-order/state checks pass; immediate demand5.524->1.983 ms and capture
1.271->0.373 ms. The earlier isolated numbers should not be treated as the actual
default-profile closure. Later8–9 ms expansions still occur after metadata intent
ends; the current continuation uses the existing worker for proven contractions
of an internally frozen completed family. Rejection diagnostics distinguish absent
exact estimates from changed captured inputs; no broad fallback is relaxed.

Latest combined actual-input run (19:08) passed81 checks with zero dropped
trace records and zero later media/native/world holds during either Fireball.
Packet-to-animation was70.568 /87.400 ms, with whole-action maximum frames
33.613 /45.598 ms: the target remains unmet and the combined changes did not
produce an overall improvement. First required-set contraction deferred optional
selection, but the second did not. The continuous actor UV certificate did not
reduce the47 cold atlas outputs; it is not evidence that their cause was fixed.

Next qualification is narrowly scoped to measured work: exact private readonly
selection ownership avoids recopying/recomparing1900 path maps; source headers
invalidate optional planning only when they can change the participating estimate;
the existing finite actor packet retains its resolved base closure for optical-role
projection. Atlas diagnostics now distinguish absent preparation (including missing
textures) from rejected prepared materials. Independent review confirms a missing
actor-source attempt is currently not retried, but the actual47 misses still need
live attribution. Existing native Factory constructor timings are forwarded into
the frame profile to decompose indivisible construction overruns. Root owns live
measurement; motion owns demand/worker capture, interaction owns actor closures,
feedback owns atlas diagnostics and plan/anti-slop/anti-OOP review.

Root's follow-up blood geometry changes hoist per-flight camera/source operands
and directly assemble the original two rectangles per particle. The unchanged
MultiMesh buffers/painter ownership pass 10,656 recorded checks; 24 native
view/age samples retain exact scene and receiving-field bytes (604 checks).
Alternating CPU medians were 169.745 -> 140.065 ms for 320 samples. The eviction
policy remains the existing oldest-two scan; typed local pin/resident maps reduce
its 1,996-entry benchmark from 0.851 to 0.489 ms (471 pins), with the existing
109 pressure/role/accounting checks passing. These are isolated CPU figures;
combined live improvements remain to be measured. No graphical reduction,
new prediction, server change, or user-preview restart is authorized by this work.

Continuation evidence (2026-10-15, before the next combined live run):
`.runtime/player-runs/20261015T181917.584355Z` passes 81 actual-input checks,
zero dropped trace records, and zero later media/native/world holds during both
Fireballs. Packet-to-first-animation remains 68.105 / 81.210 ms; server dispatch
is separately 584.109 / 424.387 ms. Whole-action frame maxima are 33.060 / 35.780
ms. The previous 11-frame, 202.508 ms impact hold did not recur in two runs after
required publication stopped consuming the world-preparation budget for future
images. Proposed-step environment readiness still takes priority; full future
source ownership remains intact. The tenfold latency/no-spikes objective is NOT
achieved.

Next measured work stays within that objective: exact reducer snapshot reuse,
immutable actor media selector reuse, removal of redundant log subtree copies,
optional metadata preparation using the existing worker, and prepared native
atlas output/style binding. Root owns real player-command profiling and blood
impact sampling; motion owns SDK/demand work; interaction reviews exact
authoring/trace/blood output; feedback owns atlas qualification and independent
plan/anti-slop/anti-OOP review. No server edits or user-preview restart.

Blood impact qualification: the existing received-shape worker now prepares the
two actual per-particle landing amounts, retaining only particles whose shapes
touch that tile at either amount. A single exact reveal can select those arrays
by its authored landing time; simultaneous reveals use the original general
evaluator. No blood fact, geometry, light, timing or upload format changes.
167,993 checks compare all 83 recorded receiving versions across 2,019 exact
landing boundaries against the immediate pre-change evaluator. Alternating
9-run CPU medians for 1,660 warm evaluations are 76.097 -> 5.133 ms. The expanded
worker/adoption test passes 56,881 checks including negative finite schedules,
missing-preparation fallback, overlap, reverse playback and cancellation. Live
impact savings are still to be measured. A preceding structural cache attempt
was slower (77.481 -> 109.948 ms) and was removed; it is not part of the change.

Current user target: reduce the remaining 284–313 ms client packet-to-animation
delay by at least 10×. Root changes whole-group component admission to require
only cues due at the proposed display boundary, while preparing later received
cues during the cast. Full retention/media ownership and pre-commit readiness
remain mandatory; replay seeking retains its full closure. Measure later cue
holds as well as the first visible frame so delay is not merely relocated.
Motion reviewer owns SDK intake/parsing; interaction reviewer owns presentation
compilation and metadata enumeration. Feedback reviewer independently tracks
plan adherence, anti-slop, anti-OOP and event/graphics correctness. Use real
recorded inputs for isolated checks, then the same live Gallery player actions.
No server edits, prediction, graphic reductions or user-preview restart.

Latest optimization scope: prepare assets while the player targets, but reduce
the underlying cost rather than moving an 800 ms stall earlier. Selection hints
remain optional, bounded by the media budget, and never predict/commit outcomes.
The actual received group retains its exact readiness and event order. Trace
targeting frames as well as submit-to-response/preparation/animation separately.
The user has a separate server worker; this task fixes client costs and reports
observed server waiting separately.

The user also requested replacing large resource loads used for tiny queries.
First concrete change: bake exact authored hand/body optical samples in ignored
`.derived/surface-sockets` sidecars; metadata workers admit them, renderer lookups
do no IO/readback, and full optical textures remain on the GPU. Missing/stale
sidecars retain the original CPU path. Qualify every baked finite point and
assembled top-layer ownership/placement against the original images. Preserve
color buffers where pixel picking still consumes them. Audit other consumers
(palette statistics, profile variants, alpha/bounds) before changing roles; do
not claim a GPU-only consumer while any real CPU reader remains.
Root owns attachment integration and validation; feedback reviewer owns measured
media demand costs, motion reviewer owns optional selection lifetime/coverage,
interaction reviewer owns the compact sample baker and blood-worker qualification.
They also check plan adherence, anti-slop and anti-OOP; no graphics/rule changes.

Qualified compact data: 2,147 registered authored sources now use 17,824,463
bytes of sidecars for 750,885 finite optical queries. Only demanded source records
are loaded. This is CPU query data; original GPU textures remain unchanged.
All sample bounds/byte ranges pass. The initial 156 Gallery/sandbox sources pass
55,948 independent Godot byte checks and 3,512 assembled mirrored/scaled/four-view
placement checks with optical CPU images removed. A further 24-source sample
spanning all 19 effective authored clips/eight facings passes 8,576 checks.
Unregistered poses, non-solid sources and creature sources without the existing
attachment reference retain the original fallback; the bake invents no geometry.
Evidence: `.runtime/surface-socket-full-bake-summary.json` and
`.runtime/surface-socket-full-library-byte-checks.json`.
Persisted palette operands pass 110 checks against full source scans, including
replaced source/incomplete cache recovery; existing cached Gallery operands load
in approximately 0.4–0.7 ms. The prior bounded scan was roughly 13–19 ms.

Latest live run before the final profile/owner changes:
`.runtime/player-runs/20261015T143629.031782Z`, original Gallery door/move/haste/two
Fireballs, 81 checks, zero dropped trace records. Hover p99 is 23.458/28.310 ms;
whole-action worst frames are 54.115/36.009 ms. First animation after submit is
1091.9/686.7 ms, of which server dispatch is 645.1/396.3 ms. Complete packet to
animation still costs 415.5/271.0 ms. These are blockers, not smooth-play claims.
The original user window remained open on the same GPU throughout comparisons.

That run uploaded a 231 MB speculative monument destruction map although neither
cast destroyed the monument. The existing committed lossless page tool had not
been applied to the installed v1 manifest. Regeneration now selects 98 unchanged
numeric pages at 4.5 MiB each; 5,023 checks prove all saved bytes, actual frame/view
selection, readiness closures and settled endpoints. This reduces individual
upload size, not total artwork bytes. Upload/frame causality needs the next live
run's absolute timestamps. Root owns final live measurement; motion owns selected
normal-profile projection and preserving resource hints across a target query;
interaction owns sparse ground transforms and rebaking after Geometry is frozen.
Feedback remains independent plan/anti-slop/anti-OOP and resource-closure reviewer.

Follow-up live evidence: `.runtime/player-runs/20261015T152417.554892Z` passes
81 checks with no dropped trace records. Both Fireballs enter their component gate
with zero missing required character/environment textures. Batching the existing
18 authoritative blood cells reduces that gate from 152.6 to 112.9 ms and from
138.1 to 98.5 ms, with native effect construction/hit draw acknowledgement now last.
Required worker metadata still takes 97/48 ms, and packet-to-animation is 345/255
ms. Whole-action worst frames are 30.95/41.44 ms: no overall smoothness claim.
The second cast reveals two new floor cells and spent 4.86 ms rebuilding support
geometry. The follow-up changes only those contacts under the existing complete
revision proof. New/remove/zero-to-raised/raised-to-zero native transitions match
the frozen full-snapshot renderer across four views (354 pixel/picking, 50 support,
11 transform checks). Isolated two-support sync averages 2.308 to 0.290 ms;
new live measurement is pending. Native atlas reveal cost remains approximately
26 ms.

Review rejected the attempted membership-only resident-readiness shortcut: a
previously deferred exact-role change could be skipped when an optional source
later becomes selected. Removed it rather than adding another readiness cache.
The independent frozen-demand oracle now covers that sequence (612 checks), plus
107 actual PNG role/race checks. Full role/readiness refresh remains authoritative.
Image accounting uses Godot's `get_data_size()` instead of requesting pixel data
only to count its bytes. The existing metadata handoff checks pass 52; its known
11 ObjectDB/one Resource exit diagnostics predate these changes.

Required metadata decomposition found duplicate compact-file admission: selected
action preparation had already qualified those same files, but only the scene
received them. The session worker now consumes accepted, immutable compact records
through its existing mutex at packet boundaries. It alone updates its cache;
cancelled/unaccepted selection results, mutable records and rules documents do
not cross this mailbox. Close discards pending records and joins the worker.
Actual recorded selection/Fireball handoff passes 30 checks with identical required
paths/roles and no additional compact-file admission. Character preparation alone
falls 79.636 to 6.048 ms offline; environment/header-cache effects are not credited
to this change. Existing session retirement passes 22. The new passive fixture
reports three ObjectDB instances at exit; no functional failure. Live evidence follows.

Live confirmation `.runtime/player-runs/20261015T153934.817124Z` passes 81
checks, no dropped trace records. Character metadata is 6.086/7.753 ms; the
two-new-support boundary is 0.050 ms. Complete packet to animation is still
300/236 ms, with server dispatch 685/459 ms separately. The whole-action worst
frames are 92.881/43.810 ms: the first includes a 79.808 ms worker upload of the
61,341,696-byte chair destruction geometry overlapping the slow frame's absolute
interval (player CPU itself 25.425 ms). Do not hide that aiming-frame outlier by
reporting only frames after submission. Extend the existing lossless page tool
only to the measured chair/bookshelf numeric sheets (four sources, 36 pages at
most 4.5 MiB each), preserve current monument pages, and independently qualify
authored rectangles/selected normals/readiness before another live run.
That conversion now passes 8,192 independent Godot checks (1,288 numeric cells,
644 actual Catalog samples, all frames/four views and settled/finite closures)
plus the partial-page Python check. Existing monument pages and all 177 compact
sample source stamps remain valid. No runtime shader/provider changed.

Final live check for this batch: `.runtime/player-runs/20261015T155004.219576Z`,
81 checks, no failures or dropped trace records. Same live door, room movement,
haste and two Fireballs; the user's separate preview remained open on the GPU.
Published chair/bookshelf numeric pages are at most 4,718,592 bytes, with worker
upload maxima of 1.089/0.877 ms. Their original monolithic destruction numeric
sheets are absent from the published upload trace. The previous 92.881 ms aiming
outlier did not recur in this run; this is one observation, not a no-spikes claim.
Fireball aiming maxima are 30.850/32.857 ms, whole-action maxima 37.039/40.667 ms.
All-action worst is the door at 62.070 ms, including a 25.354 ms lighting-atlas
phase. Thus the 100 FPS/no-stall target is still unmet.

Fireball server dispatch is 663.982/437.977 ms; complete packet to first animation
is independently 313.132/283.719 ms. Within client preparation, strict JSON is
35.822/21.032 ms, canonical consumption 6.955/9.531 ms, presentation compilation
50.697/11.733 ms and required metadata 36.204/29.771 ms. Packet-to-prepared spans
131.013/74.299 ms; remaining time is after preparation and still needs work on
main-thread admission, resource readiness and native effect construction/draw
acknowledgement. These intervals must not be added to server time twice.
The worst first-cast frame includes 15.887 ms media planning (12.317 ms demand);
the worst second-cast frame has 27.654 ms player CPU, including 8.854 ms actor
sampling, 4.448 ms blood and 4.657 ms native lighting. These are remaining measured
client costs, not a justification for changing approved graphics/event order.
Full comparison: `.runtime/client-small-query-comparison.json`. Test processes
exited; the user's existing encounter was not restarted.

Other large-data consumers audited: original colour buffers still serve actual
alpha picking and top-layer attachment ownership. Shadow cookies are read once
per registered texture and consumed as complete images by shadow projection;
fixture pixels are already decoded for rendering, with emission statistics on
the decode worker. These are not replaced by guessed point samples. Palette
statistics and finite socket queries are derived data; normals/light receivers
remain original GPU media. Required normal profiles, optional selection lifetime,
bounded decode batches and lossless destruction pages retain separate tests.

Intermediate evidence: same-host live Gallery Fireball run
`.runtime/player-runs/20261015T141033.963962Z` passes its 81 command/state checks,
but selection preload regresses first targeting p99 to 47.165 ms (from 15.992).
Its 23 ms demand rebuild is a blocker, even though first animation after submit
drops from 1511 to 1040 ms. Do not present that candidate as smooth or finished.
Source and profile fixes must be remeasured together after the regression is fixed.

Current task: investigate the freeze when the player casts Fireball after entering
the large room using a live connected player and real commands, not replay as the
primary performance evidence. Trace click/selection, request queue, server execution,
response decode/admission, event preparation, native spell readiness and rendered
frames. Fix measured client stalls and move preparation earlier where it is valid,
without changing graphics or event order. Record remaining server/client costs.
Also fix the spell-level/variant popup's overlapping action-bar click ownership.
Accumulated targeting feedback: highlight the actual hovered character/object
selected by the admitted click intent; clear this temporary highlight on selection
or exit. Alt highlights disclosed active interactables. Suppress the misleading
cursor tile for subject-targeting, retain cells/AoE for ground-targeting. Reuse
existing presentation controls and keep undisclosed actors/objects concealed.
Acceptance: actual native popup clicks select only their choice; live room-entry
and Fireball timings distinguish server waiting from blocked rendering. Reviewers
track plan adherence, anti-slop and anti-OOP; avoid unrelated renderer/UI redesign.

Latest follow-up: party portraits belong LEFT with larger 48×64 art and HP
values; initiative uses smaller 36×48 art across the top, matching original
Pygame roles. Keep portrait art/frame/HP padding separate. The Fireball hover
grid must not flash between the selected-prefix eligibility cells and hovered
affected cells while queries arrive. Keep eligibility stable and replace only
the authoritative hover result atomically, preserving stale-response/authority
guards and never using held visual data to authorize a click. Review is
plan-adherence/anti-slop/anti-OOP; scope is these two UI corrections only.

Follow-up implemented: legal cells and continuation positions now come from the
selected-prefix preview. A valid same-prefix pointer move retains the last full
authoritative footprint until the matching reply replaces it. Invalid targets,
UI capture and changed command authority still clear it; held display data never
authorizes a command. The real-reply gesture checks pass 38, compact interaction
77, and whole-player native capture 36. Six rendered pending frames preserve both
the ground marks and their publication revision. Capture uses recorded server
replies with controlled delivery; it is not a new live-server performance run.
Portrait geometry passes 426 checks and HUD boundaries 78, including an error/Copy
row that stays clear of the left party. Native pending/published captures are in
`.captures/targeting-native/`. The user's running encounter was not restarted.

Latest user correction supersedes the log's content-sized layout: keep a tall
upper-right panel extending down to just above End Turn, resizable and translucent,
with its toggle on the right and no Escape dismissal. Keep exact authored combat
wording/math, put expanded details beside their own event rather than a detached
bottom pane, and publish entries at the corresponding presentation beat while
preserving attack/damage/death causality. Implement real prospective spell/AoE
hover previews and ordered targeting using the SDK, with cursor intent matching
click behavior. Restore top initiative and left-side party portraits (latest
explicit correction; supersedes the earlier right-side message), distinguish inspection from turn authority, and replace
permanent resource prose with compact action/bonus/reaction/movement/spell-slot
indicators and tooltips. Respect the user's existing action-bar design. Fix repeated
death/death-save animation from the actual final encounter recording. Investigate
the idle text flicker/frame hitch with measured native idle frames and identify its
actual owner before changing preparation/network behavior. Preserve approved lights.
Owners: interaction agent log/timing, motion agent targeting/cursors, feedback agent
lifecycle plus plan-adherence/anti-slop/anti-OOP review; root portraits/resources,
idle investigation and integration. Acceptance includes saved real events, native
interaction/hover/occlusion, and an idle measurement, not assertion counts alone.

Implemented in this continuation: the tall log remains open on Escape, its toggle
sits beside End Turn, and exact authored math expands inline. Generic action logs
publish at contact rather than recovery end; existing damage/aggregate causality
gates remain. Already-downed stabilization/death transitions hold their terminal
pose instead of replaying a fall. Top initiative and left party portraits use
displayed snapshots; inspection is independent of command ownership. Resources
use compact native amounts/tooltips, including grants above nominal capacity.
Native flow containers keep these banks clear of the log and targeting controls
at narrow sizes. Retained player action icons use their actual discovery actor.
Spell hover uses the same admitted ordered-prefix operation as clicking, including
repeated recipients, stale-response guards, actual affected-cell fill and disclosed
recipient/allocation labels. Ordinary cursors/hover labels share click intent.
Action tooltips expose native baseline dice/save/attack/cost facts without claiming
a target-adjusted hit probability. Existing approved light/shader artwork is unchanged.

Evidence: `generated/log_publication_timing_checks.json` covers four real journals
(2,154 checks); `generated/recorded_lifecycle_checks.json` covers the user's 221
operations plus real revival/terminal transitions (1,111 checks). Native log UI
checks pass 20; responsive actor HUD geometry/resource checks pass 408. Real SDK
Fireball/Magic Missile hover queries preserve state revision/cursor/command number
(13 checks), and the actual player gesture path passes 28 checks against those
saved replies. Ground occlusion/fill/cache checks pass 241 across four quarters
and two elevations. Snapshot-driven HUD boundary checks pass 77, and recorded
player inventory/action-bar projection passes 77. All reports identify their scope;
fixture UI dispatch is not represented as a new backend action.

The fresh connected 20-second native idle sample did not reproduce notice flicker
(p99 8.55 ms, max 10.36 ms). The user's late recording did reproduce boundary
stalls while hidden AI turns published 244 legitimate light-only tile changes.
The ground overlay now reuses unchanged geometry/order; immutable media demand
owners avoid repeated equality scans (251 independent frozen-reference checks).
The paired profile retains original 181–221 arrival timing and exact final state.
It reduces measured sorting work and median boundary cost, but worst-frame
variation remains; this is not a claim that gameplay is spike-free. Full artifacts
are under `.runtime/late-idle-*`. No status-message recurrence was observed in
either measured run.

Final residue-index qualification: use the existing consumed changed-tile ledger
only with matching canonical owner and complete base/current revision proof;
initialization, seeking and missed publication retain the full-scan fallback.
51 checks include actual opportunity-hit deposits, light-only changes and removal.
The final identical native replay reaches the exact sequence-221 canonical state:
blood indexing median 1.277 -> 0.013 ms; late-traffic p99 18.717 -> 15.306 ms;
worst late frame 29.895 -> 21.075 ms; fully warm idle p99 7.999 ms. Real update
frames still exceed the 10 ms target, so this does not certify spike-free gameplay.
Full-window native targeting captures pass 22 checks after waiting for real icon
decoding, using a SubViewport-local pointer without moving the user's mouse.
They show Fireball hover before spending, ordered Missile allocations and the
open log; the original recording and canonical state remain unchanged. The fixture's
generic caster has no authored portrait and retains an explicit initial fallback.

The user returned to the live Gallery encounter. First fix the media preparation
error that blocks playback, using the actual required-worker/player boundary and
the saved encounter journal. Add a Copy button beside the displayed error which
copies its exact message and concise playback diagnostics. Preserve event order
and source-readiness gates. Then put the grid and targeting previews above ground
but below walls/actors; keep elevation and G toggle. Narrow the translucent combat
log, allow resizing and vertical content growth, remove empty detail space, and
improve highlighting/expansion without rewriting recorded combat text. Remove
generic HUD instructions. The requested Pygame motion, feedback and interaction
audits remain inventories, not authorization to implement every discovered gap.
The feedback audit agent tracks plan adherence, anti-slop and anti-OOP review;
the interaction agent owns the history panel and the motion agent owns ground
overlay placement. Validate real worker completion, native UI interaction and
occlusion without changing approved lighting or restarting the user's encounter
before the repair is ready.

Implemented and checked on 2026-10-15: restored the required media worker's
completion publication (regression introduced in checkpoint 813d21f). The new
fallback assertion failed before the fix and the handoff suite passes 52 checks
after it. Replaying the user's original saved journal through sequence 31 and
preparing its real compiled group passes 11 checks; this verifies metadata, not
GPU upload readiness. Native HUD checks pass 59, including clicking Copy and
retaining the exact displayed message. History checks pass 17 against 181 real
recorded log entries, preserving their text. Ground grid/preview tests pass 193
native pixel and picking checks over four quarters and two elevations; the
existing draw merge checks pass 1,012. An actual launch exposed one extra picker
assumption about QuadMesh, now fixed by excluding noninteractive overlay entries.
The corrected live Gallery launched with PLAYER_READY and no script errors.
The original failed journal remains under .runtime/player-runs/20261015T105810.768342Z.
Full-game frame-time performance was not requalified in this gameplay/UI repair.
Headless media tests retain their existing shutdown ObjectDB warnings.

## Current continuation — finish the existing spell batch

### User correction: interactive Studio performance and clutter

The user reports roughly 10 FPS in the delivered Gallery Studio. Previous native
correctness runs did not qualify interactive playback speed. Measure the actual
normal-clock Studio at the delivered resolution and recording, without capture
readbacks or fixed presentation steps in the measured interval. Separate UI CPU,
world CPU, GPU, preparation stalls and display-clock progress. Compare the same
movement/spell intervals before and after changes.

The current Studio correction prioritizes first usable publication and a coherent
timeline for the actual recording. Current-view media and native readiness must
remain exact; optional preload and unrelated preview work must not delay opening
it. Present each recorded movement and multi-projectile action coherently, remove
repeated empty Fireball/placeholder pages, and keep genuine missing work and the
original component details inspectable. Derive grouping from existing event and
component ownership: inspect actual projectile counts before treating a display
duplicate as a renderer defect. During playback/recording, vertical following must
keep the active published row visible using the same geometry as drawing and input.
The latest screenshot correction requires genuinely single-height default strips:
one actor's Run segments use the existing body sampler's selected source and keep
real interruption gaps; simultaneous native deliveries share a source-preview
strip with their unchanged individual rows available by expansion. Review the
whole recording as a multiframe sequence with Follow, not isolated stills alone.
The latest explicit correction changes the initial horizontal scale from full-run
Fit to a useful seconds-to-pixels view. Keep Fit available as a deliberate control
and follow the active work both horizontally and vertically. Previews must use
their row space legibly; tiny art pinned to the upper edge of a tall strip is not
accepted. Preserve aspect ratio, exact sources, time positions and access to all
recorded deliveries when changing display sizing. The reported 9.8-second startup
is also still unacceptable: reduce unnecessary selected-load and global native
warmup work without declaring required source/render readiness complete early.
Measure first usable publication and later cold source/seek costs, so deferring
work does not turn the opening improvement into playback stalls.
The output is a responsive single Studio preview and usable tracks; source artwork,
delivery counts, damage ordering and the recording/reducer remain unchanged.
Lossless source paging remains a separate unqualified experiment until its exact
region/pixel and playback checks run; the rejected atlas reservation is not part of
this UI correction.

The user's latest correction removes split view from Studio. Keep one preview
and the recorded faction selector. Startup reads, compiles and plans media for
only the selected original journal. Load another faction on demand through the
existing worker, retain the old preview until the new frame is ready, and preserve
pause/resume intent. Use the existing navigation anchor to map the same recorded
event/phase, including its disclosed boundary fallback; equal elapsed seconds are
not assumed to mean the same action. Reuse already-loaded audience indices.
Single-view Studio does not require a shared retimed comparison schedule or
admission of the other journal. Keep the explicit Recording comparison APIs and
their tests, all original journals and the faction picker. No second renderer
should remain running and no private reducer state may be merged.
Hide routine environment, carried and native-effect lighting detail by default.
The optional Lighting tracks view and explicit text filtering retain their exact
data. Actions, animation, effects, damage, conditions, sound and genuine missing
work remain visible. Do not show exploration/state-only bookkeeping as empty
tracks. Optimize
measured avoidable work without changing approved
lighting, spell art, source clocks, event ordering or gameplay. Scope review:
plan-adherence, anti-slop and anti-OOP reviewers check these boundaries. Acceptance
is real playback measurements plus faction-switch/seek/loop and light-track access checks,
not an assertion count alone.

The target is now explicitly 100+ FPS (under 10 ms per frame). Run uncapped
native measurements, separating ordinary client-issued Gallery gameplay from
Studio overhead. Fix vertical track following after the frame-rate blockers;
thumbnail preparation must not hold the visible row layout or playback clock.
The user explicitly rejects high average FPS as justification for freezes.
Qualification must include cold and repeated spell playback, the slowest frames,
p95/p99 and counts above the frame budget, both in Studio and the ordinary player.
Preparation waits count against playback progress; moving a stall outside the
reported average is not an optimization. Keep iterating on the measured blockers
without changing approved graphics or event order.

The user's next instruction supersedes the two-spell limit: finish migrating the
existing sandbox spell batch into the shared client/Studio pipeline. Aid, Bless,
False Life and Sacred Flame are explicitly deferred; migrate the other 30 existing
capabilities now. Their remaining artistic timing/placement tuning does not block
functional integration. Do not expand into new Factory artwork or spell audio.

1. Register the existing native sources/staging as data for all non-deferred
   spells. Support their existing cast, flight, strike, spray, area and attached
   roles, including source tails and actual light/material inspection channels.
2. Compile from real server spell/application/damage/heal/condition events.
   Source delivery counts and recipients stay authoritative. Persistent native
   visuals belong to disclosed condition/effect instances and end when those
   owners disappear; sandbox demonstration hold times and follow-up actions
   never become game facts. Existing `reactionCastBinding` authoring must use the
   actual condition application when a reaction has no separate SpellFact;
   reuse the ordinary cast/body path without inventing another event.
3. Expose organized real spell recordings in Studio through the same reducer,
   renderer and timeline. Preserve missing/unsupported channels honestly. Make
   every non-deferred migrated spell selectable rather than stopping at two
   representative examples.
4. Validate coverage for the whole batch in one pass, plus native family checks
   for projectile, area, attached/heal, persistent apply/remove and reaction
   paths; exercise Studio selection, seeking and looping. Reuse the established
   acceptance tests instead of repeatedly qualifying individual pixels.
5. Keep a plan-adherence subagent active; perform anti-slop/anti-OOP review of
   event ownership and shared helpers. Finish this batch before handoff, with a
   concrete per-spell coverage report and only the four explicit deferrals.
6. Follow the user-supplied sequence screenshot handoff: add a thin observer of
   existing Studio seek/publication, bounded recordings/ranges/cameras, final
   pane plus timeline images, and shared Factory clip/contact-sheet packaging.
   Follow the active component lane during playback; retain actual active-row
   IDs and missing work in receipts. Validate transient, persistent and paired
   replays. No backend actions, renderer fork or separate presentation clock.
7. User correction: the measured 20.6-second native-thumbnail preparation is
   unacceptable for navigation. Bake previews once for all available spells and
   four camera quarters, save them as native Godot Resources on disk, and load
   those resources on selection across application restarts. Reuse one forward
   source simulation for successive samples; preserve the existing source clocks,
   colour, alpha and thumbnail resolution. Invalidate changed visual sources and
   authoring without using event/actor identities as the cache key. Measure fresh
   process loading separately from the offline bake; target approximately 0.2 s
   for thumbnail availability and report the actual result. Keep bounded memory
   and explicit fallback for missing/stale previews. This is thumbnail artwork,
   never a replacement for the live native VFX renderer.
8. Additional requested Studio study: a complete sorcerer excursion/combat on
   the existing large Lantern Gallery map. Compose the encounter with published
   roster/deployment recipes, then record ordinary SDK choices/preview/commands
   for movement, door opening, several included spells, enemy attacks and an
   actual Shield reaction. Keep both original faction journals, verify the real
   facts and register the run in the existing capability Library. Do not inject
   outcomes or change game rules. Qualify native replay, seeking and the run's
   spell tracks; retain any genuine missing presentation channels.

## Scope and acceptance

The initial Fire Bolt/Magic Missile slice established the shared path. The
current continuation activates the 30 non-deferred existing capabilities through
that same path. The sandbox remains the fast authoring fixture; the actual player
and Studio consume real server recordings and the same compiler, reducer,
timeline and renderer. The four deferred spells remain outside this batch.

Aid, Bless, False Life and Sacred Flame are **not accepted by the user**. Timing
and positioning for **every spell** still need tuning. Technical checks establish
mechanics, not artistic approval; retain this status in the Factory handoff.

Requested behavior: a real spell action produces authored native charge, release,
travel and contact, with actual recipient damage reactions and body feedback.
Boundary: SDK recording/live events → shared presentation → game/Studio viewport
and its inspectable component tracks. Inputs must be recorded server packets,
including successful hits and Shield-blocked deliveries. Expected output is
ordered, seekable native playback with explicit source and event ownership.

## First implementation chunk

1. Keep the SDK and event tree unchanged. Correct the existing spell compiler so
   ordinary spell attacks without an application envelope also get delivery, and
   respect authored `cast.enabled`. Multi-application roots must not duplicate
   projectiles. Actual application count, targets, cancellations and damage facts
   remain authoritative.
2. Select the existing Factory clips and phase/placement authoring by spell ID.
   Generalize the already-tested native source sampler and source-clock/transform
   helpers. Do not use sandbox delivery counts, local contacts, body actions or
   finite condition holds as gameplay facts. Emit ordinary component records with
   stable event IDs, source pointers, start/duration, recipient and phase.
3. Render those components in the player's World3D with the qualified floor/body
   depth pass. Preserve the existing blood/class path. Each replay pane owns its
   mutable native instances. Different spell appearances must not share one
   mutable palette or optical override: retain finishing per compatible appearance
   group and optical data per occurrence. Only active groups use render passes;
   any unavailable input/capacity remains explicit, never silently recoloured.
4. Reuse the approved normal-light bridge and body hit material. Existing applied
   damage facts own receiver reactions and150ms hit flashes; no flash on blocked
   or zero damage. Preserve Colour/full-material choice and explicit unsupported
   full-material sources. Keep ordinary environment/character lighting unchanged.
5. Studio must show native phases and renderer-driven light/body channels with
   actual source previews or an explicit missing reason. It must use the same
   component timing as the viewport. Seek, loop, pause and camera changes must
   neither duplicate events nor retain effects from a previous occurrence.

## Validation and next chunks

Use existing successful Fire Bolt and Gallery Magic Missile journals, plus the
Studio Magic Missile/Shield recording (which contains no applied damage). Check
the real event tree → cast/release → delivery → damage/death ordering, every
missile recipient, replay seek/loop and independent panes. Native checks must
inspect actual scene instances and frame output, not just source availability.
Preserve the user's running sandbox while tests use their own finite processes.

After this proof, expand transient spell families through data. Persistent effects
must attach to existing authoritative instance owners: conditions for Bless, and
temporary-HP grants for False Life, including removal/suppression and separate
recipient ownership. Add real lifecycle recordings before claiming those paths.
Reuse the shared body-surface compositor; do not add another condition system.
Unmigrated capabilities stay visible as gaps in Studio.

## Review

- Plan-adherence reviewer: guard the first complete real-event path; prevent
  polishing individual spell art from displacing migration.
- Anti-slop reviewer: reject duplicated clocks, fabricated events/contacts,
  single-selection state leaking between spells, and availability marked as
  rendered without evidence.
- Anti-OOP reviewer: retain data components and the existing compiler/sampler
  owners; no per-spell class hierarchy or second event/reducer framework.

## Progress

- Source/production ownership and available recordings reviewed.
- Shared hit envelope restored to 150 ms; real playback and feedback checks pass.
- Open Arm Invocation now resolves both authored hands before taking their
  midpoint, with shared preparation/release placement: 2155 headless checks and
  211 native checks passed across the five supported poses/four camera views.
- Fire Bolt and Magic Missile now compile native preparation/travel/impact
  components from actual events. Recorded delivery/damage checks pass168/168;
  independent SDK/displayed snapshot checks pass581/581.
- Studio exposes native source phases, exact source-light keys and receiver
  material children. Real-recording channel/trace checks pass643/643; native
  full-material mode is explicitly inactive when Colour treatment is selected.
- Shared material-source checks pass46/46, sandbox playback708/708 and source
  choreography1370/1370. These do not substitute for production native checks.
- Production Play tests found and fixed missing optional geometry metadata and
  a seek/preparation diagnostic error. Source roots now stay hidden until their
  native render/light masks are assigned, fixing reset-time engine errors.
  Native optical image requirements enter the mandatory media plan before its
  readiness result. Unchanged-query readiness is checked by the playback test.
- Native thumbnails pass504/504 across six phases and four camera views,
  including cold-tail reconstruction and paused rotation. Actual Studio controls,
  48 visible source previews and seek/reseek pass8/8. The shared sandbox's final
  two-loop regression passes692/692, with clean native logs.
- Native trace evidence now requires conservative on-screen submitted bounds
  and a completed draw. Bounds checks pass41/41; this is not a guarantee of
  nonzero or unoccluded pixels.
- Final production playback passes3347/3347 on Windows Forward+/Vulkan, with
  no engine/script warnings or errors: actual 30FPS1× and60FPS2× playback,
  seven recorded deliveries, four actual damage flashes, zero Shield damage,
  retained tails, reverse seek, loops, final canonical state and resource cleanup.
  Full/Colour changes remain inside the actual recipient's assembled mask;
  paused restoration is byte-exact for the scene, native effect pass and material
  source textures. The mask measurement changes only output alpha, preserving
  scene submissions while measuring the original alpha coverage.
- Independent native pane ownership passes68/68 with the actual Amber/Blue
  journals: private worlds, source instances, materials and emitters; the same
  recorded event phase; mutation isolation; and reverse/forward seeking in each
  pane while the held peer's native output remains byte-exact. All qualification
  processes exited with clean logs and the user's sandbox stayed open.

## Reproducible recording fixtures

These checks require the existing local journals; none fabricates an event or
replaces an SDK after-value.

| Fixture | Journal under `.runtime/` | Operation | Deliveries / actual damage |
| --- | --- | --- | --- |
| Fire Bolt hit | `compact-magic-missile-20261013/amber/journal` |29|1 /1|
| Magic Missile hits | `gallery-route/journal` |22|3 /3|
| Shield blocks Magic Missile | `studio-cases/magic_missile-seed3/amber/journal` |2|3 /0|

Run `tests/native_spell_playback_checks.gd` with Windows Godot Forward+ for the
production display path. `tests/native_spell_thumbnail_checks.gd` qualifies the
source swatches; `tests/native_spell_studio_checks.gd` opens the actual Studio
controls with `--recording=res://.runtime/studio-cases/magic_missile-seed3/amber/journal`.
That case's perspectives render identically, so Studio correctly keeps one pane.
`tests/native_spell_panes_checks.gd` separately uses both real journals to check
private native ownership in two production replay worlds.

These are correctness checks, not performance measurements: their frame
intervals include instrumentation and framebuffer readback. Reports and captures
stay under `.runtime/native-spell-*` and `.captures/native-spell-*`.

## Explicit current boundaries

The30 activated source selections use `authoring/native_effects/index.json:/spells` to
select existing Factory clips and schedules. Native source-light inventory lives
beside each selected source bound; `tools/native_spell_light_intake.gd` extracts
the actual nodes, animation keys and update modes for review. This is inspection
metadata, not a second light animation or gameplay light system.

Each active finishing profile has a native pass sharing the player's floor/body
depth. Different finishing passes have not been qualified for mutual VFX-to-VFX
depth sorting. The current bridge also does not certify scenery/refraction,
transparent-body depth, particle collision or spell audio. These remain explicit
work, rather than implied support from a successful floor/actor fixture.

The paused material check holds scene submission fixed. A separate diagnostic
that hid receiver meshes changed a small overlapping native transparent region
despite unchanged effect clocks and support depth. That scene-submission ordering
behavior is not fixed or certified by the material check. Unsupported geometry
uses the existing clear-depth fallback; these fixtures do not qualify every
creature/outfit or equipment changes during flight.

Phase thumbnails use the shared Factory sampler. The full receiver material is
inspectable on the live assembled actor; a dedicated body-material thumbnail is
still an explicit inspection gap. Aid, Bless, False Life and Sacred Flame remain
deferred; artistic timing/placement tuning remains open for every spell.


## Current batch integration status

All 30 non-deferred source selections and their existing staging are registered.
Delivery metadata separates area roots, individual applications and Ice Knife's
actual burst effect. Nested support/combat source overrides remain in the imported
manifest. Production selections exclude offline fixture bodies, target placement,
delivery counts and demonstration Shield attacks.

Lifecycle data names the actual disclosed condition/spatial-effect IDs and the
specific legacy media replaced. Native opening, held pose and closing windows
are source-time metadata; actual owner UUID lifetime/removal/suppression governs
the effect. These are held native poses, not newly authored or artist-approved
seamless sustain loops. Web's ground geometry admits only disclosed unsuppressed
cells, while restrained recipient markers remain independently owned. Light's
native appearance does not duplicate the authoritative optical emitter.

Whole-batch event integration passes 3,387 checks across all 30 spells and both
original audience journals (`generated/studio_spell_batch_checks.json`). This
includes canonical commit parity and actual native phase/lifecycle ownership.
`generated/native_spell_batch_render_checks.json` records nonzero native frame
contribution and seeking for every spell, retaining the initial failures and
focused corrections rather than claiming one all-green invocation. The earlier
Fire Bolt/Magic Missile results remain the more extensive initial-slice evidence.
The four deferrals and artistic tuning requirements remain unchanged.
## Current batch recording inventory

Every entry below has original server journals for Amber and Blue. Native phases
are selected through shared authoring; recipient counts and persistent lifetimes
come from those journals. This is the existing sandbox batch, not all game spells.

| Spell | Native phases | Persistent native owner |
| --- | --- | --- |
| Acid Splash | cast, flight, impact | — |
| Chill Touch | strike | — |
| Eldritch Blast | cast, flight, impact | — |
| Fire Bolt | cast, flight, impact | — |
| Fireball | area, cast, flight | — |
| Guiding Bolt | cast, flight, impact | — |
| Ice Knife | area, cast, flight | — |
| Magic Missile | cast, flight, impact | — |
| Poison Spray | cast, spray | — |
| Produce Flame | flight, impact | — |
| Ray Of Frost | cast, flight, impact | — |
| Scorching Ray | cast, flight, impact | — |
| Sleep | area, cast, flight | — |
| Web | area, cast, flight | spatial_effect |
| Bane | attached | condition |
| Command | attached | condition |
| Mage Armor | attached | condition |
| Sanctuary | attached | condition |
| Shield | attached | condition |
| Shocking Grasp | attached, cast | — |
| Burning Hands | attached | — |
| Thunderwave | attached | — |
| Cure Wounds | attached | — |
| Healing Word | attached | — |
| Guidance | attached | condition |
| Resistance | attached | condition |
| Light | attached | condition |
| Thaumaturgy | attached | — |
| Shield Of Faith | attached | condition |
| True Strike | attached | — |

Deferred: **Aid, Bless, False Life, Sacred Flame**.

The capability Library retains all other planned game spells and interactions as
visible work. No available recording is substituted for an unrecorded capability.

## Actual Studio Library qualification

`generated/native_spell_library_checks.json` preserves the multi-run result for
real Fireball → Mage Armor → Shield Library navigation. All three actual case
selections, native phase pointer selections, nonblank source previews, production
occurrence submission, reverse/reseek and selected interval Out→In loops passed.
Mage Armor is retained from the first three-family run; the corrected Fireball
and final Shield runs each pass 35 checks. Persistent-row looping proves that
selected real interval, not by itself the complete condition lifecycle.

The first run's Fireball failure is retained: source intake confused GPU trail
storage lifetime with visible emission and requested an excessive thumbnail age.
After correcting that metadata, the serial native preview path passed 29 checks
but needed roughly 80 seconds for 52 visible/all-view samples. Native spell swatches
now use the existing queue/cache with at most eight independent source worlds.
They retain the same 60 Hz source replay, native materials, draw-completion fence
and 15 second per-source timeout. Suspension and generation reset/cancellation are
covered. That intermediate empty-thumbnail-cache Fireball demand took 20.628
seconds; Shield's 28 samples took 0.791 seconds. The user rejected the Fireball
latency. These are historical runtime-simulation baselines, superseded by the
saved-preview implementation below; they are not the accepted navigation cost.

A separate initial batching harness error is also retained: it read a null
SubViewport assigned-world property rather than the actual Camera3D world. The
test now guards this and requires all requested cases to finish. Acceptance uses
the result plus engine-log inspection, never an empty failure list alone.

Current captures are `.captures/native-spell-library/{fireball,mage_armor,shield}`
with `-studio.png` and `-selected-source.png` suffixes. Fireball's corrected serial
and batched runs retain one exit-time ObjectDB instance warning; no script/render
errors occurred in either accepted run. Final Shield has no ObjectDB instance
leak; verbose donor RGBFloat→RGBAFloat conversions and orphan StringName notices
remain. All owned native test processes exited. This qualification does not
change the four explicit spell deferrals or confer artistic approval.

## Saved preview resources and the Gallery expedition

`tools/bake_studio_spell_previews.gd` reads real recordings and saves the unchanged
native source sampler's output in paged Godot Resources. Runtime selection loads
those frames through a bounded cache; it does not resimulate an existing baked
sample. Visual source/timing/quarter identity is independent of event and actor
UUIDs. Source dependencies and import settings invalidate affected derived pages.
The files live under `.derived/studio-native-previews/` and remain Git-ignored.

The final all-30 bake completed 260 phase/view histories, 28,016 sample positions
and 544 compressed pages in 174.974 seconds, including 43.123 seconds of offline
journal indexing. The two Gallery journals then added 172 pages in 50.428 seconds,
reusing 1,812 existing samples. Both finite processes exited successfully without
script/render errors; donor warnings and exit-time ObjectDB instances remain
recorded in the bake evidence. These durations are offline generation, not
interactive thumbnail loading. Fresh-process load and actual Library navigation
measurements are qualified separately.

The new `gallery-sorcerer-expedition` case uses the existing 73×39 Lantern Gallery
and an ordinary level-five premade Sorcerer with an explicit scenario Shield
reaction grant. Its 60 successful SDK commands open the entrance door, cross the
furnished hall, cast Ray of Frost, Scorching Ray, Acid Splash, Fireball, Magic
Missile and Chill Touch, then Dash farther into the room. The enemy caster's
Magic Missile triggers the Sorcerer's real Shield application and removal. Both
original audience journals are preserved; no damage, reaction, destruction or
movement outcome is injected by the client. The compiled presentation is 42.85
seconds. `tools/studio_gallery_spell_capture.py` reproduces the encounter and
registration, and `generated/studio_gallery_spell_case.json` records its evidence.
Native full-run/seek/loop qualification is separate from successful SDK capture.

The corrected full Windows Forward+/Vulkan run passes **2,196/2,196** checks and
exits successfully. It covers both independent canonical endpoints, 34 native
occurrences across all seven spell/reaction families, 43 actor-follow camera
samples with no offscreen caster, reverse/reseek and an actual Fireball interval
loop. Evidence is `.runtime/studio-gallery-spell-checks-native.json`, with paired
Studio and native-source captures in `.captures/studio-gallery-spells/`.
No script, rendering or texture-upload errors remain in this run. Three ObjectDB
instances are reported at process exit, so resource cleanup is not certified.
The fixed-60-Hz paired correctness harness took 170.6 wall seconds for the 42.85
seconds of presentation; it is not an interactive frame-rate benchmark.
The original failed oversized-texture logs are retained separately. This result
does not mark unrelated missing Gallery presentation channels as implemented.

### Corrections exposed by the long recording

The Gallery timing check exposed a shared compiler bug: a prior spell application's
body-recovery tail could postpone the next recipient's authoritative damage
commit. Application commit time now follows its logical contact and dependent
commit markers; visual recovery still retains its complete authored duration.
Original packet order and the existing ordered commit gate remain unchanged.
Both Gallery streams pass 2,166 checks, the combat timing suite passes 1,750,
independent compiler/snapshot parity passes 581, and the complete 30-spell batch
passes 3,387 after this correction. All saved preview ticks still resolve without
rebaking: 28,016 for the library and 10,236 for the Gallery.

The initial native Gallery run also exposed two 37,632×1,536 numeric sheets for
the destroyed slender monument, wider than the device limit. They are now
losslessly reflowed to 5,376×10,752; the explicit catalog layout adapter changes
only texture path and source rectangle. All 784 saved/reloaded cells are
byte-identical, and 3,149 checks cover all 98 frames in four views plus preload
closure and the terminal destruction frame. Original artwork, pivots, transforms,
timing and lighting are unchanged. Derived files remain Git-ignored and are
reproducible with `tools/prepare_environment_texture_layout.py`. Media warmup
checks the actual device's 2D texture dimension limit before upload or readiness
publication; its suite passes 67 checks. This is a dimension guard, not a claim
that every possible GPU allocation failure is handled.

A separate terminal-state native check passes 30/30 with a clean engine log:
both panes submit the actual destroyed monument frame 97 at 42.847554 seconds,
with both 5,376×10,752 numeric textures resident. The queried RTX 5090 dimension
limit is 32,768. `final-monument-studio.png` records the rendered remnant; it is
not an assertion inferred solely from successful texture creation. This focused
check preserves the earlier full 2,196-check report.

The user launch adds `--view-size=12` alongside actor/track following. A separate
31-check native test at the real Fireball contact +150 ms confirms that the
caster, target and all 49 disclosed affected-tile bounds fit both panes, and the
same zoom survives reverse/reseek. The active track is followed in the captured
Studio UI. Evidence: `.runtime/studio-gallery-spell-checks-framing.json` and
`.captures/studio-gallery-spells/fireball-framing-studio.png`. This run has no
script/render errors and retains one exit-time ObjectDB warning. The optional
view size changes initial Studio framing only; it does not alter spell size,
lighting or gameplay cameras.

## Current performance continuation — target not met

The earlier paired captures establish rendering correctness, not the delivered
Studio design or performance. Studio now has one selected-faction viewport;
lighting-detail tracks are opt-in. Optional thumbnail prewarming pauses during
playback, and incomplete thumbnail images no longer block publication of row
geometry or vertical following. No actor, spell, lighting or reducer clock was
changed by those UI corrections.

The earlier clean uncapped ordinary-player baseline is
`.runtime/player-replay-profile-serialized-native-stable-camera.json`: median
8.264 ms, p95 20.991 ms, p99 30.840 ms, maximum 355.350 ms, with 1,847 frames over
10 ms, 35 over 33.333 ms and four over 100 ms. It completes the actual recorded
42.848-second Gallery playback outside Studio, with no presentation or shader
errors and three existing exit-time ObjectDB warnings. Initial preparation takes
19.120 seconds and is reported separately; the selected playback interval still
includes first uses and preparation waits. This is not proof of cold client-issued
command performance. The requested under-10-ms frame budget remains unmet.

The prior completed measurement,
`.runtime/player-replay-profile-source-cache-and-receiver-prep.json`, had median
7.839 ms, p95 27.825 ms, maximum approximately 361 ms and five frames over 100 ms.
The new run reduces the long-frame count, but does not establish an all-frame
100-FPS result or erase the failures recorded below.

Completed work and its bounded evidence:

- Exact adjacent actor-frame changes copy only `frame_uv` into the native light
  atlas's output and receiver materials. Complete binding/material changes,
  replaced targets and missed versions use the original full copy. Headless
  uniform parity passed 1,786 checks; native capped/uncapped framebuffer parity
  and lifecycle passed 232. Later receiver-shell preparation passed the parent's
  241-check native suite. Prepared shells carry no future atlas addresses or
  material state; cancellation owns their disposal.
- Required native occurrences alone gate current playback. Already-received
  groups can prepare within a four-second horizon and a maximum of 24 optional
  occurrences. Source and hit-material preparation share one per-frame work
  allowance. Optional work retains private hidden instances until consumed or
  cancelled; it does not publish future state or enlarge required image pins.
  Real Gallery preparation/state checks passed 93; source/surface promotion and
  cancellation ownership passed 13. The latter uses passive prepared resource
  stand-ins and does not assert rendered pixels.
- Actual disclosed SDK choices start resource/authoring preparation before a
  first cast has an event or recipient. The choice worker owns passive metadata;
  scene construction remains on the scene thread. Ten checks cover the real
  Sorcerer choices, immutable inputs and shared-budget admission. Current native
  source/hit qualification passed Fire Bolt 1,012 and native materials 48 with
  clean logs. The final source-generation/pass-reuse batch requires its separate
  full regression; these earlier counts do not cover later edits automatically.
- Live Gallery pressure exposed a full sort of roughly 2,000 resident sheets
  every frame to select at most two evictions. Bounded oldest-two selection
  preserves required/preload pins, exact accounting and the existing release
  limit. Its selection-only median fell from 6.382 to 0.828 ms in the focused
  pressure fixture; 100 checks passed, and the existing media suite passed 67
  with its known seven exit-time ObjectDB warnings. This excludes actual GPU
  texture and CPU-image destruction, so it is not a claimed total-frame gain.

The shared 2-ms preparation allowance limits admission between atomic operations;
it cannot interrupt a single constructor, program preparation or resource release.
The 24-occurrence limit is a count, not measured VRAM. Existing texture residency
budgets still apply. New `media_texture_create`, `media_publish_accounting`,
`media_release_cpu`, `media_prune_select` and `media_prune_retire` timings separate
upload/accounting/release work in the next live profile. They are nested inclusive
phases and must not be added to their parent totals. Continue measured native and
live qualification; do not treat the median or the test counts as completion.


### Acceptance gaps after the subsequent native failure

The later full replay exited with Windows native heap-corruption status
`0xc0000374`. A retry reported particle-shader source inconsistent with the
selected file: the disk trail shader has 43 lines, while the diagnostic refers
to line 98 and `hash(uint x)` from another source. These are observed failure
symptoms. Overlap between background resource loading and material/shader
compilation is being investigated; it is **not a confirmed root cause**. The
saved constructor-variant integration was disabled at that stage pending qualification.
Do not treat a partial/crashed run as a new performance result.

The completed Fire Bolt/Magic Missile/Shield native regression passed 4,031
checks, including exact terminal condition UUID membership in canonical state,
source retirement, sleeping-pass ownership and weak-reference draw callbacks.
That narrower success does not override the subsequent full-replay crash.
Acceptance still requires:

- A clean complete native replay on the final enabled source generation, with
  no shader-source mismatch, native crash or unreported preparation failure.
- Fresh uncapped ordinary-player and Studio measurements, including cold and
  repeated client-issued casts, all preparation waits, p95/p99, maximum frame
  time and counts above 10 ms and 100 ms. Existing median improvements are
  insufficient for the user's all-frame target.
- Attribution of remaining live media pressure through the new upload,
  accounting and release subphases, including the real combined residency
  budget and eviction counts. Selection-only timings do not establish the
  cost of destroying native textures or CPU images.
- Final UI checks on that same stable build: one visible faction preview,
  selected-time faction switching, seek/loop, readable FPS/frame-time overlay,
  hidden optional lighting details and active-track vertical following. Follow
  must publish current row/input geometry while cold thumbnails fill their
  own cells; it must not wait for unused camera-quarter previews.

The UI/timeline work remains within the requested scope. The selected faction
still has its own reducer state; no simultaneous second faction renderer is
constructed. Existing hidden seek/loop preparation remains an isolated,
inaudible candidate and is frozen when ready. Optional thumbnail prewarming is
suspended while playing. These changes add no spell semantics, renderer clock,
new authoring framework or visual treatment. The four deferred spells and the
existing artistic timing/placement qualifications remain unchanged.

### Subsequent clean run and changes awaiting measurement

The serialized-source/stable-camera replay above completes cleanly after the
native failures. That qualifies this enabled generation's complete replay; it
does not establish the earlier failure's sole root cause or qualify offline
constructor variants, which were still disabled for that measurement.

Serial native admission passes 523 checks in
`.runtime/native-source-admission/report.json`: two independent load owners,
32 fresh real trail-material scenes, 16 real Gallery constructors and completed
draw fencing. Mixed Magic Missile/Action Surge sources also check that a later
class cue cannot starve pending spell preparation. The log
`.runtime/native-shader-stress/admission-native-mixed.log` has no shader errors.
Required/future preparation checks pass 93 and ownership checks pass 15. These
are admission/state tests; source pixel parity and full frame-time qualification
remain separate.

The fixed isometric camera now derives its basis from its quarter's constant
offset, rather than subtracting a translated focus during `look_at`. The 16,000
math checks preserve camera origin/direction and eliminate basis jitter during
pan. In the completed replay, native-atlas p99 falls from 16.389 to 4.275 ms.
The same run still has a 78.519-ms atlas reveal at display time 750 ms, despite
successfully consuming 1,095 prepared receiver bindings. Staging was accepted;
projection, address assignment and other binding work still occurred together
at publication.

The subsequent atlas change stages each new static receiver's exact private
geometry projection and bounds, then admits them only for matching source,
version, view basis and viewport size. Atlas addresses and displayed visibility
are still published by the existing transaction. Native scalar reservation keys
preserve source/row ordering without repeated GDScript comparator lookups.
The focused native oracle passes 120 checks with exact first-draw pixels for
LDR, capped lighting and normal display, plus pan/zoom reuse, source-version
rejection and a stale basis already consumed by an earlier displayed frame.
Evidence: `generated/native_atlas_staged_checks.json`. This change is newer
than the completed full replay. New reservation and prepared-release timings
expose the previously unattributed part of atlas adoption; the partial follow-up
measurement is recorded below.

The current media changes skip redundant readiness work for already-ready
mandatory sheets and limit original-image releases to two per native frame,
including repeated maintenance calls in that frame. CPU-required images remain
retained, and unreleased candidates stay queued. This limits release count, not
the time of one native image destruction. Frozen-reference queue/readiness
checks pass 188; pressure and actual bounded Image ownership pass 109; real PNG
dispatch/role-race checks pass 86. Authored warmup passes 69 with seven existing
exit-time ObjectDB warnings. Optional/manual enqueue retains the original full
readiness checks, and pending image releases recheck later CPU-role upgrades.
These changes require the next complete replay and real live-command profile
before claiming an end-to-end gain. Native scene-support setter caching is under
read-only review; no such optimization is included in these results.

A subsequent **0–3-second partial replay**, recorded in
`.runtime/player-replay-profile-staged-projection-media.json`, contains both the
atlas projection and media changes. At the same first reveal, frame time is
110.389 ms versus 141.750 ms in the completed baseline; atlas time is 52.212 ms
versus 78.519 ms, and projection is 1.882 ms versus 8.581 ms. Reservation work is
now separately measured at 2.020 ms. This is a matched reveal observation, not a
full-run average comparison or isolated attribution to the media changes.

The reveal still includes approximately 20.35 ms of receiver binding, 11.43 ms
of spec/support work, 6.33 ms of address publication, 8.58 ms of world adoption,
10.4 ms of shadows and 6.27 ms of actor work. These phase numbers include nested
timers and must not be summed as independent frame costs. The next narrow change
reuses complete prepared fields only for new receivers whose source, index,
visibility, join mask and geometry still match. Candidate-local group admission
avoids registering the same staged floor material for every row; changed rows
retain the original complete binding path. Receivers are now created hidden
under the exact atlas projection parent, with candidate-owned records transferred
at admission and rejected/cancelled records sent through the existing bounded
retirement path. The combined native oracle passes 280 checks, including shared
floor groups and exact first-draw pixels. Actual WorldPreparation/Play ownership
passes 94 checks for transfer, cancellation, epoch/quarter rejection, atlas
replacement/deletion and the sixteen-node retirement limit. Evidence:
`generated/native_atlas_staged_checks.json` and
`generated/world_preparation_receiver_ownership_checks.json`. These tests do not
establish an end-to-end frame-time result.

Prepared source variants are now enabled in the production Factory after source
state/ownership qualification across all 78 selected clips: 365,149 checks pass
in `.runtime/native-source-variant-all-checks.json`. Seventy saved artifacts
cover those clips, including body-material template sources. Eight source
families pass 57 native framebuffer checks in
`.runtime/native-source-variant-render-checks.json`: six are byte-exact, while
Fireball and Thunderwave stay within the concurrently measured variance of the
original source controls. This is not a claim that all 78 clips received a new
pixel-art review. Mutable materials and source clocks remain instance-owned;
the sandbox wrapper retains its original synchronous construction API.

Variant metadata validation now runs as passive worker work rather than a
149-ms main-thread filesystem-stat batch. Pending metadata gates only new source
construction; it does not create a second presentation clock. The first
`prepared-sources-direct-atlas` run stopped at display time 3.35 seconds after
honestly rejecting a stale Factory dependency; it is a failed partial run, not a
benchmark. The subsequent `prepared-sources-direct-atlas-v2` run completes the
42.848-second recording in 46.765 seconds (display/wall ratio 0.9162), with
median 7.815 ms, p95 19.573 ms, p99 29.076 ms and maximum 354.642 ms. Of 5,021
frames, 1,801 exceed 10 ms, 24 exceed 33.333 ms and four exceed 100 ms. Initial
preparation is separately 19.756 seconds. An overlapping headless check affected
the early interval, so its first-reveal timing is not a clean before/after
comparison. Late cold-source stalls remain real; this does not qualify the
all-frame target or live HTTP input.

The first reveal's diagnostics confirm all 1,095 staged receivers used the fast
binding path; missed preparation is not the cause of the remaining publication
work. The next change factors the existing transaction into incremental scene
capture, passive support/reservation/address planning, hidden region/rank setup,
and exact-token admission. Current native validation passes 508 checks with
byte-identical first-draw received cells and framebuffer across LDR, capped and
normal display. New dynamic actor additions and same-source replacements retain canonical
reservation order; floor removals and water support origins also match the full
planner. Intervening atlas publication, source/view/visibility changes reject stale
planning and retain the original transaction. Evidence:
`generated/native_atlas_staged_checks.json` and
`.runtime/native-atlas-prefix-final.log`. Receiver ownership now passes
128 checks, including cancellation while the passive prefix task is running and
new visible/remembered source snapshots. Future sight values stay in copied
buffers and row packets until the existing publication; changed actual sight
still rejects the prefix. `.runtime/atlas-prefix-ownership-real-fix.log` is clean.
Independent source review found no remaining ownership blocker.

The first full real-player attempt with the private prefix exposed a correctness
failure that the small pixel fixture did not cover: a floor insertion shifted
retained rows, but support-neighbour reservation ranks still used their old
receiver indices. Duplicate ranks silently lost addresses. That failed run is
preserved in `.runtime/player-replay-staged-atlas-warmed-programs.log` and is not
performance evidence. Reservation ranks now use the exact future/published floor
directory; a missing prepared static row uses the shared passive geometry builder.
Duplicate reservations and incomplete worker/binding results are rejected before
publication. The follow-up actual Gallery 0–3-second run passes 5,098 checks and
admits the two major prepared prefixes (1,109 and 593 specs), then a five-spec
prefix, without script/shader errors or fallback. Four ObjectDB exit warnings
remain. Evidence: `generated/native_atlas_gallery_checks.json` and
`.runtime/native-atlas-gallery-future-ranks.log`. The first reveal is still
83.845 ms total with 26.781 ms in atlas reconciliation; the second is 53.858 ms
with 18.375 ms in reconciliation. This is a short correctness interval, not a
full-run or live-performance acceptance.

The next complete normal-clock replay, after immutable source-noise reuse,
completed without presentation failures: median 7.812 ms, p95 18.802 ms,
p99 30.618 ms, maximum 343.254 ms; 43 frames exceeded 33.333 ms and one exceeded
100 ms. Display/wall progress was 0.913. Evidence:
`.runtime/player-replay-profile-staged-prefix-immutable-noise.json`.
This still fails the all-frame target. The late movement peaks in that report
are accepted sparse deltas, not full-planner fallbacks: private-prefix disposal
alone costs roughly 6.2–8.2 ms in those frames. Subsequent bulk registration and
bounded retirement changes are being qualified separately, not credited to this
completed baseline.

The complete `complete-noise-atlas-blood` replay now finishes with no reported
presentation failures: median 8.021 ms, p95 19.867 ms, p99 26.412 ms, maximum
77.341 ms. Of the measured frames, 1,764 exceed 10 ms, 579 exceed 16.667 ms,
13 exceed 33.333 ms, and none exceed 100 ms. Display/wall progress is 0.920;
initial preparation is 24.348 seconds and remains separately visible. Evidence:
`.runtime/player-replay-profile-complete-noise-atlas-blood.json`.
This is ordinary normal-clock Play replay, not live commands or Studio, and it
still fails the requested all-frame budget. The 750 ms reveal spends 29.814 ms in
atlas work, including 11.025 ms binding, 5.568 ms material synchronization and
4.311 ms address publication. Private atlas disposal at those boundaries is now
0.004–0.005 ms; bounded scene retirement is measured separately (maximum 3.075 ms),
so the configured 2 ms allowance is not a hard bound on an indivisible destructor.

The subsequent exact planned-removal change prepares list offsets and initial
group ranks after the same known removals; publication still requires exact
removal IDs and current group identity, material, rank and user-count proofs.
The original removal order and interleaved retained binds remain unchanged.
Native qualification passes 1,316 checks with exact first-draw cells/framebuffers,
including complete floor replacement, partial removal, missing prepared rows,
changed groups, water and stale input. The real Gallery 0–3-second replay passes
5,098 checks and now actually admits all 1,095/557/3 prepared receivers in the
three reveal batches. First-reveal binding is 8.007 ms in that run; its total
frame is still 73.861 ms, atlas 28.496 ms. This short run cannot establish whole-run
or isolated improvement because the shared shadow/media fixes are also present.
No script/render errors occurred; four existing ObjectDB exit warnings remain.
Evidence: `.runtime/native-atlas-planned-removals.log` and
`.runtime/player-replay-profile-atlas-planned-removals.json`.

The next narrow atlas change prepares the existing output transport and style
uniforms while its material is private. Admission checks the same source proof
and exact viewport identity/HDR/cap; ordinary synchronization still reads current
hover and water time. Native first-draw qualification passes 1,400 checks with
byte-identical receiving and final pixels, including hover/time changes after
preparation. Evidence: `.runtime/native-atlas-prepared-outputs.log`. No timing
gain is claimed before the next full normal-clock replay. Passive counters now
separate prepared bulk binding from ordinary dynamic binding, and dynamic/static
receiver/output full copies, so remaining reveal work can be attributed.

The source generation in the complete replay includes the final immutable
procedural texture corrections: all 78 source-state cases pass 365,149 checks;
exact noise and private-material ownership pass 1,337 checks; the finite
first-frame census passes 239 checks. All 70 prepared source packets were rebuilt
honestly. These checks preserve source pixels/clocks and are not whole-frame
acceptance. Blood loading also passes 304 native checks: six final images and
120 actual 64×64 fields are byte-identical to the prior renderer. Preparing the
existing floor/air receiving pages before their first deposit removes the
measured second-viewport creation stall; continuous blood sampling remains a
measured blocker. Actual candidate retirement ownership passes 140 checks.

A diagnostic shallow material-copy alternative was rejected without changing
production. For 47 fresh modular receiver materials, copying the accepted
uniforms costs 1.04–1.08 ms versus 3.03–3.06 ms for `duplicate(false)` followed by
shader replacement; the other sampled material families are also slower.
Duplication additionally realizes previously unset defaults, so strict raw
parameter snapshots differ; this alone does not establish a visible source
mutation. Evidence: `.runtime/native-atlas-material-duplicate-probe.json`.
No further framebuffer qualification or implementation is justified for this
slower candidate. The next full replay separates output-material adoption,
address publication and resize costs before choosing further staging work.

The subsequent full `full-optical-blood-shadow-equipment` run also completes
without presentation failures: median 8.092 ms, p95 18.573 ms, p99 24.456 ms,
maximum 72.223 ms; 1,699 frames exceed 10 ms, 413 exceed 16.667 ms and eight
exceed 33.333 ms. Display/wall progress is 0.959, with 23.700 seconds of initial
preparation. Media holds are zero, but sixteen world-preparation hold frames
remain. Evidence: `.runtime/player-replay-profile-full-optical-blood-shadow-equipment.json`.
The first reveal still costs 27.230 ms in the atlas; the target remains unmet.
This full result includes the qualified source, blood, optical media, shadow and
equipment work and is not an isolated attribution or a live-input/Studio result.

A second experiment privately prepared replacement registry containers under
exact source/group/removal proofs. Its native matrix passed 1,513 checks, but the
real Gallery check exposed the decisive limitation: the two major prefixes also
contain ordinary-new binds and could not use this narrow replacement. The
1,095-row reveal still spent 7.028 ms in bulk publication, of which 6.134 ms was
ordered binding/group/ownership work and only 0.886 ms was registry insertion.
The 0–3-second run passes 5,098 checks with four existing ObjectDB exit warnings,
but the first frame remains 71.800 ms. Evidence:
`.runtime/player-replay-profile-atlas-private-registry.json`. The replacement
experiment was archived under `.runtime/atlas-registry-experiment` and reverted;
only passive timers remain to distinguish ordered ordinary binds, group
registration/repair and private receiver-directory release. No registry
replacement or claimed speed gain is part of production.

The next full `full-condition-media-waits` replay completes without
presentation failures: median 7.702 ms, p95 17.940 ms, p99 24.297 ms, maximum
70.739 ms, with 1,532 frames above 10 ms and seven above 33.333 ms. Progress is
0.961; initial preparation is 23.750 seconds. This remains below the requested
all-frame performance. The new diagnostics identify two unnecessary waits:
at 29.819 and 29.916 seconds, respectively eight and seven frames recapture all
1,873 receivers even though atlas jobs, static upserts and removals are all zero.
Evidence: `.runtime/player-replay-profile-full-condition-media-waits.json`.

WorldPreparation now finishes that exact empty static atlas step immediately.
It still publishes the normal world receipt; dynamic actor/fixture admission,
visibility, camera and lighting continue through ordinary atlas synchronization.
The native matrix passes 1,416 checks, including byte-identical first-draw cells
and final images after actor movement/material changes, visibility, camera
pan/zoom/rotation and a new dynamic actor. A static removal still enters
preparation. `.runtime/native-atlas-empty-static-native.log` is clean. The next
full run must verify that the actual two waits disappear; this small correction
does not solve the remaining first-reveal or dynamic material cost.

The measured fixture-flame ordinary binds now prepare only hidden receiver
nodes through the existing shell API. No future material, shader clock, frame,
position or atlas address is sampled. Actual publication consumes the shell and
binds the current fixture sample; an obsolete atlas parent rejects transfer.
Unused adopted shells share the existing bounded retirement owner. The real
WorldPreparation/Play ownership suite passes 176 checks, and the native atlas
matrix passes 1,463 with byte-identical receiving cells and final framebuffers in
LDR, capped and normals views, including a fixture frame changed after private
preparation. Logs `.runtime/flame-shell-ownership.log` and
`.runtime/native-atlas-flame-shells.log` are clean. The next real Gallery run must
confirm the eleven new flame receivers use these shells and measure binding
cost; this is correctness evidence, not an all-frame performance result.

Actor graph and layer construction now uses the same constructor under the
existing hidden WorldPreparation owner. Passive future loadout samples come only
from received Timeline segments; exact rig/appearance/equipment, epoch, quarter
and source-cache ownership gate adoption. Current animation/material sampling
remains live. The worker forks the lazily filled creature-shadow memo. Headless
candidate/loadout/cancellation checks pass 453; actual Gallery playback stages
47 reveal layers, adopts 55 including startup, and its six actors at 3 seconds
produce a byte-identical full framebuffer after original direct reconstruction.
The bounded run measures first-reveal actor synchronization at 1.173 ms (0.339 ms
adoption), versus the earlier 5.259 ms observation. The entire reveal still takes
67.958 ms, including 4.118 ms actor sprite sampling and 28.585 ms atlas work.
This correctness-instrumented interval is not final FPS qualification. Evidence:
`.runtime/actor-preparation-checks.json`, `.runtime/actor-preparation-native-checks.json`
and `.runtime/player-replay-profile-actor-preparation.json`; the native process
exits successfully with four existing ObjectDB exit warnings and no script or
shader errors. Production actor sources remain frozen for the full replay.

New private actor layers now initialize only the ordinary neutral condition
material through the existing binder and the same exact material key used by
Play. Current conditions still replace that binding at admission. Focused
headless checks pass 623; the actual Gallery 0–3 second native comparison passes
with all six actors and the full framebuffer byte-identical to direct
construction. An authored Hidden renderer-input control applied at admission
also matches direct construction exactly, then restores the original pixels
without changing canonical state or time. Both frozen captures settle the same
published camera before comparison. Evidence is
`.runtime/actor-neutral-preparation-checks.log`,
`.runtime/actor-neutral-native-checks.log` and
`.runtime/player-replay-profile-actor-neutral-preparation.json`. This bounded
correctness run is not whole-run performance acceptance; it exits with the same
four ObjectDB warnings and no script or shader errors.

Actor source binding now has one implementation shared by Play and hidden
construction. A staged layer may bind a valid received/default-rest source frame
only when its original colour/optical media is already resident; this advances
no graph, actor transform or published state. Private atlas preparation copies
only output/receiver materials, with no dynamic receiver, address or geometry.
The exact source, condition, texture, geometry, destination, mode and view proofs
gate reuse; only the existing adjacent ordinary-frame UV certificate permits a
changed source version. Rejected materials take the original full-copy path,
and cancelled material stores use existing bounded retirement.

Focused material admission/cancellation checks pass 341, recorded actor ownership
623, the existing frame-copy uniform oracle 1,786, and the native staged-atlas
matrix 1,463 with exact source cells/framebuffers. Actual Gallery 0–3 second
playback adopts all 47 privately prepared actor outputs and is byte-identical to
direct reconstruction. The actual Hidden-at-admission control rejects its old
neutral receiving copies, matches direct construction and restores exact pixels.
At the first 750 ms reveal, only eleven fixture-flame full copies remain;
actor sprite sampling is 2.328 ms, atlas material synchronization 2.329 ms and
the complete atlas 25.044 ms. The frame still takes 60.524 ms. These observations
come from a correctness-instrumented bounded run, not final whole-run FPS
qualification: `.runtime/player-replay-profile-actor-material-preparation.json`,
`.runtime/actor-material-preparation-checks.json`,
`.runtime/actor-material-native-checks.log` and
`.runtime/actor-material-atlas-staged-checks.log`. Native Gallery exits with the
same four ObjectDB warnings; the focused atlas/native shader logs are clean.

Fixture flames now use the same private material-only preparation beside their
existing hidden receiver shells. Their original Texture2DArray, alpha pedestal,
source/destination owners, quad, mode and view must match. The first actual
fixture frame may advance one source version; the copied version remains old so
ordinary synchronization copies all three current source uniforms. No fixture
clock, geometry or address is sampled early. The accepted static-prefix route
also performs this dynamic material proof. Cancellation, atlas replacement and
unused admission release all private material owners through bounded retirement.
Exact material checks pass 376, candidate ownership 212, and the native atlas
matrix 1,475 with identical first-draw cells/framebuffers in LDR, capped and
normals modes. Actual Gallery 0–3 second playback reuses all 21 staged fixture
output/group owners and all 47 actor outputs. Its full framebuffer remains
byte-identical after direct actor reconstruction; the separate fixture matrix
qualifies original-versus-prepared flame pixels. The first reveal's eleven
fixture groups cost 0.297 ms versus 3.391 ms in the preceding bounded run;
eleven full frame-index copies remain intentionally. Complete atlas time is
24.818 ms versus 25.044 ms and the frame is 60.394 ms versus 60.524 ms, so this
pair establishes the smaller construction block, not an overall FPS gain or
acceptance. No media/world holds occur in this interval. Evidence:
`.runtime/flame-material-preparation-checks.log`,
`.runtime/flame-material-ownership-checks.log`,
`.runtime/flame-material-native-staged-checks.log`, and
`.runtime/player-replay-profile-actor-flame-material-preparation.json`.
Only the same four Gallery exit ObjectDB warnings remain; focused logs are clean.

Immutable prepared source data sharing is now qualified within the explicit
adapter policy. Material-free ArrayMesh geometry and read-only animation,
curve/gradient data may be reused; materials, particles, players and sampled
clocks retain per-occurrence ownership. Both procedural-noise and constant-data
decisions use the same fail-closed write-target check: authored nested resource
writes stay private, while method tracks, unresolved intermediate paths and
Resource-valued animation keys reject sharing. Actual PackedScene peer ownership
passes 60 checks (`.runtime/native-constant-resource-checks.json`); the all-78
original/prepared source-state suite passes 365,279 checks, and ten native source
families across three ages pass 71 controlled pixel checks. Isolated construction
measurements are 3.722 ms for Chill Touch and 1.777 ms for Sanctuary. Those figures
are not a paired whole-run or startup benchmark.

The subsequent full normal-clock Play replay
`.runtime/player-replay-profile-full-actor-shell-constant-data.json` completes
with no presentation failures and zero media/world hold frames. Median frame time
is 7.806 ms, p95 17.787 ms, p99 23.081 ms and maximum 75.240 ms; 1,600 frames still
exceed 10 ms, 349 exceed 16.667 ms and five exceed 33.333 ms. Display/wall progress
is 0.967; this run's initial preparation is 23.685 seconds. These are full-run
measurements, not an isolated attribution to source sharing or actor/shell staging.
The first reveal consumes all eleven prepared flame shells, but still costs
31.543 ms in the atlas, including 6.470 ms for 47 actor output and 58 dynamic
receiver material copies. Removing preparation holds is a completed correction;
the requested all-frame budget, live commands and final Studio acceptance remain
unmet. No graphical treatment was changed.

The subsequent real client-issued Gallery run passes 311 checks with no failures:
27 legal commands include seven spell types, repeated Fire Bolt, actual Shield
application/removal and 35 committed movement steps. Its active command interval
is defined by the earliest `start_frame` through the latest `end_frame` in
`.runtime/player-runs/20261015T063758.495631Z/live-command-trace.json`; it includes
all reply waits and animation between commands, but excludes initial loading and
the final idle period. Those 8,101 frames measure median 9.161 ms, p95 16.562 ms,
p99 23.662 ms and maximum 53.983 ms. There are 3,247 frames above 10 ms, 386 above
16.667 ms, 28 above 33.333 ms and none above 100 ms. The complete loading-inclusive
profile still has a 124.837 ms maximum, so the command-interval result must not be
presented as a cold-start bound. Evidence:
`generated/profiles/2026-10-15T08-39-33-gallery-live-spells.json` and the run's
`player-live-checks.json`. The all-frame target remains unmet.

Required source metadata now carries conservative PNG byte sizes through the
existing completed-worker handoff before optional family discovery. Accepted
family estimates retain priority; new paths use their raw size with the current
CPU retention role. Epoch and actual received-group checks still precede adoption,
and size metadata grants no decode, upload or readiness credit. This avoids
classifying a known required source as unknown and discarding otherwise affordable
optional warm sources. Budget/demand checks pass 247, accepted-operation
handoff checks pass 49 and source/publication latency checks pass 46; a new live
measurement is pending. The headless latency
fixture now tests its actual metadata/source/environment/boot boundary, rather
than treating a Player outside the scene tree as proof of native startup readiness.

The later standalone live Gallery run
`.runtime/player-runs/20261015T071234.455288Z` passes all 311 checks across 27 legal
commands. Its command-span filter is frames 6,955 through 15,880 inclusive from
`live-command-trace.json`: 8,926 frames, median 8.151 ms, p95 16.098 ms, p99
22.649 ms and maximum 49.974 ms. Counts above 10, 16.667 and 33.333 ms are 2,616,
379 and ten; none exceed 100 ms. All 73 demand refreshes report zero unknown
required paths, qualifying the metadata correction against the earlier cache
collapse. Evidence is `generated/profiles/2026-10-15T09-14-10-gallery-live-spells.json`.
This run includes the actor/flame preparation and cookie changes but precedes
the shared preparation allowance below. It measures the ordinary player, not
Studio, and still fails the all-frame target. Initial loading is outside this
command-span distribution.

The shared preparation allowance now lives in Play's existing per-frame passive
record. Required uploads and the next received canonical world boundary precede
optional source warming and bounded retirement; those existing consumers share
one 2 ms admission allowance. Completed worker polling remains available at zero
allowance. A completed optional PNG may free a decode slot when it blocks a real
required request, without granting publication/readiness credit. Optional source
work retains its exact epoch/group/queue ownership. Legacy first-visible native
presenters remain required atomic work and are explicitly charged; indivisible
construction/destruction can exceed the allowance, so it is not a hard 2 ms frame
bound. Focused admission checks pass 12, native source/hit ownership checks 18,
and media checks 78 (the latter retains seven existing exit-only ObjectDB warnings).

The first policy rotated the pending world boundary alongside optional work and
introduced 46 world-hold frames totalling 458.358 ms; that policy was rejected.
Restoring the actual pending boundary's first turn produces a complete normal-clock
Gallery replay with zero media/world holds and no presentation failures in
`.runtime/player-replay-profile-shared-preparation-world-priority.json`:
5,375 frames, median 7.466 ms, p95 16.805 ms, p99 22.019 ms, maximum 60.309 ms;
five frames exceed 33.333 ms and none exceed 100 ms. Display/wall progress is
0.967852 and initial preparation is 23.363 seconds. The native log retains four
existing ObjectDB exit warnings. These results qualify readiness and progress;
intervening source/material changes prevent attributing the whole-run difference
solely to the shared allowance. Live client-issued commands and final Studio
performance still require the same-generation follow-up.

A bounded native A/B rejected reserving the light atlas at 8,192 × 4,096 during
startup. In the same 0–3 second interval, the 750 ms reveal measures 59.493 ms wall,
45.181 ms CPU and 21.981 ms atlas time with ordinary capacity, versus 59.706,
45.486 and 21.511 ms with the reservation. Removing the 1.278 ms resize does not
improve the worst frame; the second reveal rises from 41.228 to 42.286 ms. Both
runs have zero preparation holds, while setup rises from 23.535 to 24.720 seconds.
The extra 192 MiB nominal HDR target allocation is therefore not adopted. The
existing `--reserve-atlas-height` option remains diagnostic only; production
capacity is unchanged. Evidence:
`.runtime/player-replay-profile-atlas-reserve-current.json` and
`.runtime/player-replay-profile-atlas-reserve-4096.json`. This isolated rejection
does not replace the outstanding full replay/live/Studio acceptance.

The source-only paging candidate extends the existing lossless numeric layout
adapter for the two Slender Monument sheets: 49 whole-cell pages per channel,
1,536 × 768 pixels each, with legacy monolithic-manifest compatibility. Live
after-values select their exact endpoint pages; workshop destruction admits and
pins its finite animation page set before starting its existing clock. Source
edits and Python syntax checks are complete, but the generated manifest remains
version one. No page generation, native parsing, byte/pixel, animation-readiness
or upload-timing qualification has run. It is not an enabled or accepted
performance improvement, and it does not delay the current Studio UI correction.

The actual single-view Studio checkpoint passes 18 functional checks across the
42.848-second Gallery recording, exact seeks and two loop wraps. Follow remains
active through 160 frames of hidden loop preparation with no recorded lost-follow
times. Original delivery counts remain unchanged: two Magic Missile casts produce
six flights, Scorching Ray three flights, and Fireball one cast/flight/area. First
publication takes 24.395 seconds with 336 of 789 selected sources resident, proving
that unrelated optional sources no longer all gate opening, but not instant startup.
Normal playback measures median 9.418 ms, p95 21.893 ms, p99 28.378 ms and maximum
62.547 ms, with no frames above 100 ms. The all-frame target remains unmet.
Evidence: `.runtime/studio-checkpoint-native-checks.json`,
`.runtime/studio-profile-studio-compact-startup-checkpoint.json` and
`.captures/studio/checkpoint/`.

Visual inspection of that checkpoint still found a lost action heading and
Fireball Follow selecting residue instead of its active area. The subsequent
source fixes retain action/lane context in the existing ruler, choose the newest
causal action before its useful phase, and retain an active same-phase sibling.
The focused real Gallery checks pass 86/86, including Magic Missile flight and
Fireball area context; the revised native visual checkpoint remains pending.

Startup stage attribution then exposed 19.1 seconds in the loader: about 8.2
seconds reading both journals, 8.17 seconds comparing/recompiling them and 2.64
seconds planning their media. Removing two earlier discarded media plans did not
justify retaining four admissions for one preview. The current selected-journal
loader therefore omits comparison and unselected-audience admission entirely;
the other original faction loads on demand and maps through the existing causal
navigation anchor. This is the requested single-view behavior, not a new timing
system. The global native-source warmup is unchanged. Qualify cold selection,
same-event faction switching and round trips through undisclosed phases, stale
request cancellation, resume intent, seeks and loops before claiming the new
startup result. Prior checkpoint timings above do not measure this latest path.

The selected-journal loader now passes 78/78 headless checks on the actual Gallery
and Hide recordings. Only the selected journal is admitted/planned, even when the
unopened audience path is unavailable. The other real journal loads separately;
own reducer clocks, event-phase navigation, undisclosed-row round trips and
encounter-epoch rejection remain intact. Gallery Amber loading takes 4.228 seconds
and on-demand Blue 6.820 seconds; Hide takes 0.900/0.927 seconds. These are headless
loader timings, not native first publication or a paired startup benchmark against
the earlier 19.097-second loader. Evidence: `.runtime/studio-single-view.json`.
The global 72-source native warmup and the all-frame target remain outstanding.

The subsequent single-strip source change resolves movement windows through the
existing `Tracks.samples` winner in compiler order and keeps every raw component
unchanged. Numbered multishot samples and hit testing share the published layout;
expansion exposes each original delivery. The actual Gallery display regression
passes 181/181, including motion winners, exact mini-preview selection, expanded
delivery IDs, opportunity-attack gaps, Follow context and index immutability
(`.runtime/studio-follow-checks.json`). Final qualification is the requested
full-recording sequence with actual visible Follow and action/lane context, plus
the new native startup/faction-switch checkpoint. No artistic or performance
acceptance follows from this display projection alone.

The latest display sizing pass starts at 240 pixels per second and retains Fit
as an explicit control. Phase windows allocate preview spacing by the actual
simultaneous source count; aspect-preserved images are centered in their rows.
The real Gallery checks pass 209/209 for source/click identity, slot bounds,
centering, explicit Fit and forward/backward horizontal Follow. Its three-Magic-
Missile window has room for 66.4-pixel square previews rather than the previous
roughly 24-pixel slots. This is layout evidence; root's multiframe native capture
still decides whether the displayed art and following are usable. Startup remains
open, including the user's rejection of the reported 9.8-second result.

The saved startup continuation derives warmup requests from the selected
recording's actual native phase, hit and persistent rows. Studio's empty host
requests no sources; only currently required source keys gate publication, while
four-second lookahead and other selected sources use optional preparation. The
ordinary player's full-catalog startup remains separate. Actual source instances,
hit-specific material readiness and renderer draw checks retain their existing
owners. Source review found and corrected an eagerly recomputed fallback plan,
continuous drawing of retained unused warmup sources, and old-preview optional
warmup taking priority over replacement preparation. Warm samples now request
one draw; candidate ownership suspends only the old preview's optional warmup,
restoring it on cancellation/publication or a ready loop candidate's freeze.

The resulting actual Gallery checkpoint passes 29 checks, including the selected
faction, seeks, loops and visible Follow, with no reported functional failures.
First publication is 7.432 seconds from process start, or 5.131 seconds from Studio
initialization (the driver reports 5.215 seconds). Use the process-start number
for user-facing startup: this is still not instant or accepted. All 336 required
sources are resident then; none of the 453 optional sources is required to finish,
and 9 of the 19 selected native sources are warmed with zero current native keys
pending. The full 42.848-second normal-clock playback measures median 10.990 ms,
p95 22.513 ms, p99 30.323 ms and maximum 70.822 ms, with display/wall ratio 0.953543.
The all-frame target remains unmet. Evidence is `.runtime/studio-readable-scoped.log`
and `.runtime/studio-profile-studio-readable-scoped.json`. The process was retained
as the user's preview after reporting completion; this is not an exit/cleanup
qualification. The requested full multiframe visual review remains separate from
these functional and timing checks.

The final bounded upload correction addresses a separate Studio stall: creating
the 1920×1024 Melee2/Attack1 normal texture took 44.067 ms on the main thread.
The existing four decode workers now create their private texture on native
RenderingDevice backends, after checking the device's size limit; headless and
OpenGL retain the original path. Only the completed task's main-thread publication
makes the source ready. Native checks pass 10/10 for exact GPU/CPU bytes,
oversize rejection, canceled results and close ownership; role-race checks pass
89/89, and warmup checks pass 78/78 with seven existing ObjectDB exit warnings.

The follow-up Studio checkpoint passes 29/29, including seeks, two loops and a
faction round trip. Its performance interval covers only the first 20 seconds,
not the complete 43-second recording: median 11.100 ms, p95 20.074 ms,
p99 28.523 ms, maximum 71.766 ms, and display/wall ratio 0.951985. All 453 optional
texture publications take at most 0.008 ms for main-thread adoption; background
creation still reaches 30.156 ms. This removes the measured main-thread upload
spike without establishing a whole-frame improvement. The matched first-20-second
comparison changes median 9.458→11.100 ms, p95 19.999→20.074 ms,
p99 28.395→28.523 ms and maximum 70.822→71.766 ms. Its exact publication field
falls from 44.062→0.008 ms across 453 textures in each run; aggregate frame times
barely change. This bounded comparison is recorded in
`.runtime/bounded-performance-result.json`. First publication remains
7.425 seconds from process start, and the worst room-reveal frame remains slow.
The separate 12-second standalone run reaches 66.977 ms versus the prior
59.675 ms; no shared reveal improvement is claimed. Evidence is
`.runtime/studio-profile-studio-worker-textures.json`. The preview remains open
after qualification. The earlier full 516-frame UI capture was completed and
reviewed through Scorching Ray and Fireball; this does not extend the latest
20-second timing interval. Startup, room-reveal latency and 100-FPS all-frame
acceptance remain unmet. The recording snapshot cache is deferred, with no
production cache added; independent numeric texture paging remains unqualified.
This optimization pass stops here without claiming completion of those targets.

Remaining acceptance is:

- Complete replay frame-time distribution, worst frames and preparation holds
  with the final enabled variants and atlas changes.
- Real client-issued cold and repeated spells plus movement/reveal, including
  request latency and every native preparation wait rather than replay-only
  averages.
- Honest thumbnail rebaking after the source freeze. Existing packets whose
  source dependencies changed must miss or be regenerated, never relabelled as
  current. Then measure the same normal-clock Studio with its single selected
  faction, FPS overlay and active-track following.
- Explicit Studio authoring Reload now has a narrowly qualified ownership path:
  25 native checks in `.runtime/native-source-reload-checks.json` reject stale
  dependency/bake results, load fresh same-path resources without mutating an
  existing instance, and reject an old in-flight successful result. Ordinary
  loading/seek/faction switching do not invalidate the cache. The UI wiring
  parses; actual UI-click/framebuffer/timing qualification remains pending, as
  does the separately reviewed stale error-result revision guard.

No graphical treatment changes are part of this optimization batch, and no
100-FPS/all-frame acceptance claim follows from the source or atlas check counts.
