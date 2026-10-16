# Complete the three client ownership operations

Status: user authorized planning, independent review and implementation on 16 October 2026. Initial plan independently approved; implementation incomplete. Subsequent user constraints below govern continued design and implementation. Starting checkpoint: `e920efb`.

User requested a tested stopping point, comprehensive spike/attempt handoff and
commit on 16 October. The checkpoint is documented in
[CLIENT_PREPARATION_PERFORMANCE_HANDOFF_2026-10-16.md](CLIENT_PREPARATION_PERFORMANCE_HANDOFF_2026-10-16.md),
with committed compact timing data. This is a bounded implementation checkpoint,
not acceptance of the remaining door latency or frame-time goals.

This is the completion/removal ledger for the unmet requirements in
[the existing preparation/publication plan](PREPARATION_PUBLICATION_OWNERSHIP_PLAN_2026-10-15.md),
especially §§5.1, 5.4, 7 and 11. It introduces no parallel framework or new
renderer. Review approval means the named independent reviewers have reviewed
this document and their blocking findings have been resolved; it is not a claim
of human artistic approval or achieved performance.

## Outcome and limits

Already received actions begin promptly and reach their impact/aftermath without
resource discovery interrupting playback. Ordinary small updates remain small.
Gameplay and Studio share source ownership and presentation semantics. Preserve
hierarchical event order, accepted state/display separation, source lifetimes,
independent replay reducers, authored clocks/audio, Forward+, approved textures,
lighting/cap, normals, depth, wall modes, tint and material treatments.

No backend or Factory edits, bulk spell intake, UI redesign, new ECS, local
prediction, artistic retuning, generic transaction graph or permanent old/new
runtime switch. Read current Factory host requirements from the prior plan; wall
sections and condition leases remain separately owned disclosed occurrences.
Unintegrated source capabilities remain explicit gaps rather than fabricated
gameplay or hidden source layers. Assets stay ignored and in their current place.

## Measured baseline and accounting

### User corrections to retain throughout the work

Recorded 16 October after the first two combined live runs. These are cumulative
instructions, not reasons to stop the authorized work or ask again:

- Identical modular layers/animation sheets are shared. Source identity is the
  actual layer/category/clip plus admitted authoring revision, never actor UUID,
  equipped-item UUID, transform, tint or HP. An outfit composes shared references;
  each actor/occurrence retains only mutable playback/material/pose state and pins.
- The four actual Gallery sentries have identical visual appearance/loadout once
  equipped-item UUIDs are removed. Current actor-keyed metadata resolution is
  redundant. Physical textures already share by path: the captured second run
  shows 1,833 texture creations for 1,833 unique paths, with no duplicate texture
  creation in that captured lane. Requirement counts are not load counts.
- Trust the backend's admitted payloads and the exported artwork. Asset schema
  validation, dependency/freshness scans and hash checks belong in optional
  authoring/import tools, not the action or sampling path. Use ordinary errors
  for missing/incorrect resources. Preserve actual ordered state transitions;
  do not replace necessary publication work with repeated safety certificates.
- The later user instruction is explicit: validate during tests and import
  qualification; runtime should compute directly from prepared data. Do not add
  runtime schema, source, identity or dependency proof scans around that work.
  Production uses prepared references and reports ordinary actual resource
  errors. Cursor ordering, stale-worker rejection and owner publication gates
  remain state mechanics; they do not justify repeated schema validation.
- Factory already edits native `.tres` spell/phase Resources. The client still
  reads JSON then native overlays, and spell manifest/staging JSON. Complete the
  native Resource boundary rather than optimizing another legacy adapter. JSON
  may remain an offline import input; warm actions must use admitted references
  without file/header/socket/closure discovery. `.res` is a possible binary
  packaging form, not an automatic performance claim.
- Stop making isolated modifications without accounting for the entire critical
  path. Baseline framing+parse+reduce+setup+compile alone is 31.57/25.81 ms. Removing
  all metadata and rendering waits cannot honestly promise a 10x total speedup.
  Such a target also requires removing most serial runtime resolution/compiler
  work and measuring the remainder. Do not substitute reduced source visits for
  achieved input-to-animation latency.
- Continue investigating and refining the design; record findings here instead
  of repeatedly stopping the task. Reviewers remain involved. Preserve approved
  graphics and event ordering; no server/Factory changes are authorized here.

### Current combined evidence

First combined run `.runtime/player-runs/20261016T093103.388023Z`: 81 functional
checks passed, Fireball onset 104.17/120.22 ms including final framing; a regression.
Second run `.runtime/player-runs/20261016T093859.925211Z`: 81 checks passed, onset
84.70/81.38 ms; frame means 15.01/17.53 ms and maxima 34.86/37.92 ms. Targets remain
unmet. At that checkpoint, required-component owner reuse removed repeated
preparation on unchanged cuts, but full media publication still applied future
physical roles synchronously and actor metadata remained keyed by instance
identity. The later source-boundary changes are recorded below. The second run's
source upload counts span optional background work too; they do not explain onset
alone.

The next live run `.runtime/player-runs/20261016T103903.406859Z` passed
81 functional checks. Fireball onset was 89.78/112.64 ms including final framing;
action-frame means were 14.43/17.21 ms and maxima 41.93/42.87 ms. Opening handoff
to first visible animation took 55.779/78.722 ms. The nested main-thread
`media_plan_sets` phase peaked at 4.038/5.135 ms; its source-record union still
used quadratic identity scans. This run predates the linear union and passive
constructor-source changes below. It establishes neither achieved timing targets
nor a performance improvement for those subsequent changes.

Latest completed comparable successful live run
`.runtime/player-runs/20261016T110104.141262Z` passed
81 functional checks. Fireball onset was 82.242/89.584 ms including final framing;
action-frame means were 13.7103/18.0898 ms and maxima 33.906/36.012 ms. This remains
above the onset/frame objectives. Subsequent source-clip uniform and advance
binding work is not qualified by these earlier measurements.

The later combined live attempt at 11:31 on 16 October stopped after Haste:
`hud.bar_pending` remained pending for over five seconds. There was no live
ScriptError; optional media work taking 1.2–3 ms consumed the shared 2 ms
allowance before HUD preparation could run. This failed route does not qualify
combined performance. The saved priority correction and focused checks are
recorded below. A second matched attempt started at 11:35; its timing and
functional result are not yet available at this ledger update.

Native depth/support/outline focused checks passed. The earlier Studio
`full_or_missed_receipt` publication failure was corrected; an earlier full Studio
run passed 7,155 checks. A later attempt recorded 5,374 checks and seven
prefix/endpoint failures in `generated/studio_replay_native_checks.json`.
Independent diagnosis and the native prefix probe identified a test-oracle
error: a yielded published cut was compared with every operation sharing its
clock, rather than its actual ordered prefix. The actual cuts near 1683.333 and
4745.178 ms were exact intermediate prefixes, not runtime state loss. The
focused native probe passes 1,055 checks in `.runtime/studio-prefix-native.json`.
The corrected full native Studio run subsequently passed 8,693 checks with zero
failures, errors or warnings. That run includes the material-uniform changes
below, but predates the later native-rig and trusted-parser batch; those changes
still require combined qualification. The separate 83-check source-owner proof
also does not qualify framebuffer output or performance.
The <=30 ms warm onset,
<=1 ms ordinary publication and <=10 ms steady-frame targets remain unmet.
Current working changes are not a qualified finished client. No queued-role
publication rewrite was started.

### Original comparable baseline

Latest real Gallery route: `.runtime/player-runs/20261015T235855.075072Z`.
Windows Forward+/Vulkan, 1600×960, view size 18. Door, enter Gallery, drink Haste,
two actual action-bar/target-click Fireballs. Complete final framing start to
first observed animation is 97.93/93.67 ms, including previously omitted framing
6.11/4.04 ms. JSON/envelope 7.96/5.35; canonical consumer 4.72/6.05;
queue/setup 1.07/2.47; compiler 11.71/7.90; required metadata 13.06/12.93;
main pickup/preparation/publication/render 53.24/54.84 ms. Action frame averages
15.02/16.48 ms; maxima 27.95/37.76 ms. The 81 functional checks contain no
performance acceptance assertion. Detailed profiling and a full-size SubViewport
display blit affect comparability; qualify the ordinary scene separately.

Keep nested timings for framing, parser regex/Variant/fallback, reduction,
compiler scheduling/components/traces/requirements, media actor/environment/
headers, source-role publication/queue/readiness, native construction phases,
world/atlas preparation, publication, sampling, UI, retirement and draw. Inclusive
children must not be added to parents. Report elapsed scheduling gaps separately.
Do not attribute time before the SSE record stamp to the server. Drain/correct
transport accounting within the existing protocol; preserve exact IDs/tokens.

## Operation 1 — One producer for requirements and source changes

Use existing compiled groups, MediaWarmup physical records and consumer roles.
Resolve immutable actor/environment/source closures in their worker owner once
per relevant source/actor selection revision. Keep currently displayed needs
distinct from later cue requirements. Do not gate the opening on two entire
future groups' metadata, optical masks, damage/death sheets or optional families.
Compile accepted future cues ahead without publishing their state or sound.

Publish producer-owned role additions/removals and stable references, instead of
five complete map comparisons and a reconstructed union on the main thread.
Required promotion, CPU/fixture roles, cancellation and multiple consumers must
retain their current correctness. Retained unchanged roles are not revisited
because a new operation arrived. Update readiness from changed resources, not
another full walk. Initial/global acquisition can enumerate its actual scope.
Source-size/header/socket metadata must reuse the admitted immutable records;
do not turn a small attachment into repeated large-file reads or new hashes.

Primary files: `presentation/session.gd`, `compiler.gd`, `media_warmup.gd`,
`environment_media.gd`, `encounter_media.gd`, `play.gd` handoff integration.
Remove the replaced full-set demand/proof work; do not retain it underneath a
new cache. Exit: opening vs late-cue readiness, shared-role promotion/cancellation,
ordered actual recordings and scaling with changed sources, plus measured nested
worker and main-thread demand costs. No new per-spell scheduling exceptions.

## Operation 2 — Complete occurrence preparation and exact publication

Extend existing native/component/world preparation so it owns all resources
needed at the next cue: finishing passes, optical nodes/cookies, support/depth
receivers, condition/hover helpers, feedback, audio and authoritative blood
helpers. Preparation builds private owners; sampling updates existing references,
poses and continuous authored parameters. Remove constructor/load fallbacks from
sample paths. Missing work retains the coherent displayed cut and returns to
preparation with an attributable pending reason. Silent missing rendering is not
an acceptable substitute for a synchronous fallback.

Ordinary gameplay startup uses only disclosed/currently needed source interests;
the full native catalog cannot be a mandatory gate. Existing optional lookahead
warms future accepted cues/actions under the same allowance. Keep true native
pipeline warming and the source adapter's mutability exclusions. Source-specific
adapters do not imply generic qualification of new effects.

Move every material producer, including hover/Alt, through SourceMaterial so
source/receiving/output treatments agree. Sparse atlas capacity exhaustion must
prepare a complete private repack, publish it once, and retire the replaced
owner; ordinary overflow cannot become a permanent preparing/error state when
the live set fits. Changes preserve all member geometry and source appearance.

Primary files: existing component/native/light/support/condition/blood/audio
presenters, `native_light_delta.gd`, `world_preparation.gd`, `play_hud.gd` highlight
producer, `play.gd` startup/publication. Exit: first use + impact, independent
same-source occurrences, condition/hover frame changes, remembered blood,
support membership change, atlas overflow/recovery, cancellation and no candidate
audio/trace. Compare unchanged source output to the current renderer oracle.

## Operation 3 — Incremental displayed frame and one host allowance

Use one host-frame preparation account for the displayed Play, Studio candidate,
native warming, thumbnails, UI construction and retirement. Required upcoming
publication takes priority over optional warming. The account must include real
elapsed work and cannot hide a constructor overrun behind a pre-call timer check.
Use existing owner queues; no new competing scheduler. Keep displayed playback
running while candidates prepare. Thumbnail file decoding/loading belongs off
the UI thread; graphics construction stays on its correct thread.

Remove repeated room-wide work for unchanged actors, source roles and material
operands. Make ordinary rank/membership updates touch their actual affected set;
global view changes/repack remain explicit larger jobs. Retire old trees without
an unbudgeted recursive prewalk. Avoid rebuilding outline children, feedback or
support geometry because only a pose or clock changed. Do not change approved
rendering representation just because source inspection suggests GPU expense:
measure native/atlas/root passes first. If the unchanged display loop remains
over 10 ms, report its nested actual costs and correct the dominant repeated work.

When the opening metadata/resources are already ready, handoff, role admission,
native readiness and publication are eligible in the same host frame. Only real
world/source/draw barriers justify yielding; a queue stage or allowance reset is
not itself a reason to insert another frame. Record actual work counts alongside
time: unchanged requirements revisited, sample-time constructors and room objects
touched by a small change. Each operation must demonstrate deleted work.

Primary files: `play.gd`, existing preparation/presentation owners, Studio host/
panes/timeline/thumbnail owners. Exit: ordinary gameplay and Studio playback,
seeking/looping/settings, cancellation, active spell movement, and matched
profiling-enabled/disabled measurements with startup timing.

## Native admission boundary amendment — 16 October

The current isolated replay audit of the six actual Gallery records makes 4,571
sheet/geometry resolutions for 400 distinct `(slot, sheet)` selections, 230 item
appearance selections for 13 semantic choices, and 7,413 catalog lookups for only
56 cold JSON reads. These instrumented CPU counts are not live latency evidence.
The problem is repeated resolution, not a separate GPU texture per knight.

Complete the existing admission boundary in two concrete, compatible pieces:

1. An offline body-source importer records the current approved source paths,
   dimensions, companion channels and compact attachment samples as lazy native
   metadata Resources. Share by actual layer/category/clip and admitted revision.
   Actor loadouts select these references; actor/item UUID, tint and pose do not
   create another source. Runtime no longer discovers headers, checks source
   freshness, rebuilds companion closures or joins the same source catalog.
2. An offline native-spell importer reads the current **client-approved** index,
   manifests and staging once, preserving their exact current selection, timing,
   palette and deferrals. Save one lazy metadata Resource per spell and a small
   string-path/condition-owner index. Resolve component-specific overrides and
   existing baked variant paths here. Runtime selection returns the admitted
   record directly: no manifest/staging joins, list search, recursive canonical
   serialization, SHA calculation or dependency/freshness worker. Native scene
   residency remains with the existing asynchronous Resource owner; missing assets
   fail normally. Dependency/format verification remains an explicit import-tool
   operation, not a second preparation gate.

The metadata index contains file paths, not texture/scene ext_resources: reading
it must not instantiate effects or eagerly load the library. Existing renderer
operands can reference immutable native record fields without another conversion
back through JSON. Private materials, particles, audio voices, transforms and
clocks remain occurrence-owned. NativeFactory gets its own shallow clip view for
its existing duration extension; it must not mutate a shared source record.

This admits the current approved delivery only; it does not copy the Factory,
intake new spells, alter art, or claim its JSON export is its editable source.
Rebuilding admitted metadata is an explicit import step; authoring reload selects
a new admitted revision while the previous display keeps its own references.
Verify cold/warm lookup and exact old/new source/timing operands, source sharing,
reload/cancellation and unchanged real recorded output. Keep the spell and body
removal obligations separate; neither alone completes operation 1.

The packet benchmark separately confirms that native JSON parsing is not a
speedup over native Variant parsing on these packets and changes integer types.
Do not add a recursive post-parse repair pass. The interpreted UTF-8 and full
syntax guard account for 8.42/5.48 ms on the two isolated Fireball packets; choose
a trusted-producer path only with actual scalar semantics accounted for. This is
not permission to replace ordered cursor/publication checks with assumptions.

The Studio replay regression has a different owner: a full **state** reset is not
a full **lighting atlas** replacement. Publish lighting from its prepared physical
change. An empty prepared lighting delta retains its serial; a real prepared
repack still publishes its full layout. Never suppress the atlas ordering error.

### Body source admission boundary (implementation amendment)

The body importer reads the currently approved effective rig/sheet, equipment,
geometry, normal-profile and baked socket inputs offline. It publishes a small
metadata-only native index plus one resource for each actual rig/category
(e.g. Head3), with its admitted clips. Resources contain passive path strings,
original dimensions, exact geometry/normal companion references and compact
socket bytes; they do not reference Texture2D, scenes or other artwork resources.
Only selected category resources are loaded. Actor/item UUIDs, tint, transform,
HP and playback clocks never identify a source. Actor construction composes
references and retains mutable layer/pose/material state privately.

Admission is explicit. The importer saves the index inside a new revision
directory, then atomically publishes its path through the short `current` marker
described below. Existing cache shells retain their immutable index/resource
references; reload admits the selected revision. Worker snapshots share an
immutable admission shell; lazy loads replace its small loaded-reference map
rather than mutating a map already shared with another worker. No runtime mtime,
hash or dependency scans qualify an action. Missing resources use existing
ordinary authoring errors. SourceCatalog retains the body and spell admission
shells by direct reference; it does not scan/deep-copy their dependencies.

Removal obligations: production Characters selection uses imported semantic
item bindings and layer/clip descriptors, removing item binding/category joins,
resource-sheet joins and geometry/profile joins from each actor/clip query.
CharacterGeometry uses the same admitted records for presentation and media.
Body source estimates use imported dimensions; compact sockets use imported
samples, removing PNG-header reads and socket manifest/source freshness checks
for these admitted sources. Optional encounter families compose shared layer
references; identical sentries do not resolve all clips independently by UUID.
Legacy JSON remains an offline import input, not a production fallback switch.
Environment records remain with their existing owner; no artwork is retuned.

Qualification compares exact old/new path/CPU/GPU/normal/socket/dimension data
for approved sources and the latest actual six-record Gallery route. Measure
cold import/admission separately, unique layer refs versus actor query counts,
worker phase costs and actual live onset. The 1,833/1,833 captured physical texture
publications were already unique: this boundary removes repeated metadata work,
not duplicate GPU textures, and alone implies no 10x total latency promise.

### Index revision ownership correction (implemented)

The fixed-path index strategy failed actual native qualification. In
`.runtime/native-admission-race`, repeated `ResourceLoader` loads of the same
index with `CACHE_MODE_IGNORE` or `CACHE_MODE_IGNORE_DEEP` returned null for 191
of 192 requests; `CACHE_MODE_REUSE` succeeded for all 192. Serialized threaded
IGNORE requests also failed seven of eight times. A synchronized first-load
owner alone did not solve explicit reload: re-admitting both fixed-path indexes
failed while the previous index holders remained alive. These are observations
from the current Godot runtime, not evidence that the resources were absent or
that all failures were caused only by concurrent requests.

Both importers now save an immutable `<revision>/index.res` alongside that
revision's metadata Resources. After every required file is saved, they close a
staged short path marker and atomically rename it to
`.derived/native-spells/current` or `.derived/body-sources/current`. Admission
reads that marker once and uses `CACHE_MODE_REUSE` at the selected immutable
index path. An explicitly configured body index remains a direct, caller-owned
immutable native resource path. There is no fixed-path index fallback, runtime
schema/hash/freshness check, polling loop, retry scheme or new source registry.

The existing source boundary owns one synchronized current index reference per
source kind; body admission also respects its configured index path. A cache
with an admitted shell returns it before entering the first-admission mutex.
`SourceCatalog.source_snapshot` pins both index references before dispatching
workers. Small read-only admission shells retain those references and replace
their loaded-reference maps by copy-on-write. Explicit metadata invalidation
clears only the current references, leaving previously admitted workers and
displayed sources intact. Studio performs that invalidation before its fresh
recording loader starts; packet/program invalidation remains at its later
existing safe boundary.

`tests/source_index_owner_checks.gd` passes 83 checks, recorded in
`generated/source_index_owner_checks.json`: 24 simultaneous first admissions,
a real offline native-spell rebuild, parallel reload with old holders alive,
unchanged-body revision reuse, an independently configured body index, and
ordinary adoption retaining the prior displayed revision. This qualifies
metadata admission and ownership only. It does not replace the current live
Gallery route, full Studio seek/loop, approved-output comparison or timing
acceptance; the 7,155-check Studio run preceded this correction.

## Review, implementation and acceptance sequence

1. Antislop reviewer checks deletion of repeated work, no extra framework/caches,
   realistic critical paths and no misleading timing labels. AntiOOP/correctness
   reviewer checks ownership, lifetimes, immutable handoff, thread DAG, event order,
   atlas recovery and unchanged graphics. Resolve blocking plan findings before
   production edits. A separate plan-adherence subagent monitors implementation.
2. Implement operation 1 with its removal obligations and focused observable
   regressions. In parallel after approval, occurrence work may proceed in
   non-overlapping files. Keep Play/session handoff integration owned explicitly.
3. Finish operation 2 and the shared host account/incremental operation 3. Run
   native/GPU processes serially and stop only processes launched for this work.
4. Review combined changes, then execute the same actual Gallery door/movement/
   Haste/Fireball route and a real recorded cast/reaction/multi-hit/death sequence.
   Exercise gameplay with ordinary scene rendering and Studio with seek/loop;
   neither alone qualifies the other. Fix reviewed correctness regressions before
   interpreting performance. Tests follow `dnd_engine/HOW_TO_TEST.MD` and assert
   observable cuts/resources/output, not private cache call choreography.
5. Retain the existing objectives: <=30 ms warm received-action-to-animation,
   <=1 ms ordinary publication and <=10 ms total steady frame. These are targets,
   not predicted savings. Include final SSE framing in onset; preserve separate
   transport/server timings. Report p50/p95/p99/max, every >10 ms frame by nested
   dominant cause, cold/prefetched differences and profiling overhead. Absolute
   unmet targets stay unmet; no narrowing acceptance to successful Fireballs.

Record implementation removals, reviewer decisions and measured results below.
Do not finish with just a plan or promise; the user authorized implementation.

## Review decisions and implementation evidence

Antislop reviewer approved the plan on 16 October; required removal of the old
full-set demand path rather than a cache around it. AntiOOP/correctness reviewer
approved on 16 October, retaining actual complete-cue readiness and authoritative
dynamic source/receiver truth. Plan-adherence reviewer approved after adding the
same-frame ready-path gate and before/after work counts above. Production
implementation may proceed. No performance result is implied by these decisions.

### Body/environment source boundary implementation evidence

`tools/import_body_sources.gd` now imports the approved effective body selection
into metadata-only native Resources under ignored `.derived/body-sources/`.
The current import has 237 actual rig/category Resources plus 32 explicitly
referenced loose PNG accents, 3,429 clip/slot descriptors, 21,271 source path
references and 20,851 dimensions. It changes no artwork. The current revision's
Resources occupy 74.80 MB plus a 7.32 MB lazy index; the actual six-record route
admits 23 Resources (13.50 MB plus index), not the full dependency library.
The three profile selections and native mask roles are descriptor-owned refs
with stored scalar identities. Actor/item UUID, tint and transform are absent
from their source keys. Optional families compose each actual layer/slot once.

Runtime body source resolution no longer performs item binding/category joins,
resource-sheet/geometry/profile joins, PNG header reads or socket manifest/input
freshness scans. Imported geometry keeps its admitted absolute root and optical
registration. Existing `SourceCatalog` snapshots carry the immutable admission
shell; its adoption seam merges already loaded refs for the same revision.
No interpreted recursive freezing remains: a separate cold probe measured
36.73 ms for the index and 112.30 ms across 18 actual selected categories spent
only in that walk. Ownership now treats admitted source data as read-only and
keeps only small shell/maps explicitly read-only with copy-on-write replacement.
Binary metadata deserialization is still a measured cold cost; it is not
represented as eliminated or as a warm-action latency improvement.

EnvironmentMedia now owns one immutable contribution per physical path/fixture
role and publishes those refs directly. Opening partial preparation borrows
previous complete refs until the full continuation replaces that finite scope.
The old whole-room contribution comparison/replacement was deleted. Main-thread
source demand compares stored identity→ref maps in linear reference count time;
changed references are still recognized even when the stored identity agrees.
Its diagnostics distinguish record-delta construction, interest updates and the
actual number of role entries visited.

`tests/body_source_parity_checks.gd` compares the latest six actual Gallery
records against frozen pre-change source adapters. Its initial 6,102 checks
passed; the expanded fixture now passes 12,424 exact path, CPU/GPU, geometry,
normal-set, socket-byte, source-sharing and optional-family checks. The fixed
creature fixture passes 736 checks across all 43 registered fixed rigs in
`generated/fixed_body_source_parity_checks.json`. The separate source publication
fixture passes 75 checks, including late-cue error gates and shared consumer
cancellation. These are source/CPU metadata qualifications, not a live latency
or native-frame acceptance claim; no runtime artwork or shader change is
claimed. In the matched Fireball source cuts,
opening→full changed from 443 added + 164 removed role entries to exactly 135
added / zero removed (135 actual physical role changes), and from 899 + 182 to
exactly 189 / zero (189 actual changes). All 195/213 opening refs respectively
remain retained. See `generated/body_source_parity_checks.json` and
`generated/source_requirement_publication_checks.json`.

The subsequent actual live run above exposed another retained-reference cost:
Play rebuilt its projected/combined source-record union with repeated
`Array.any(is_same)` scans. That union now preserves order through stored
`source_id` membership, retaining identity handling for the small unkeyed
transient contributions. Physical source readiness is refreshed once after the
interest-update batch, rather than once per individual change. The existing
source owner and readiness semantics remain in place; no extra registry,
publication queue or runtime validation was added.

`.runtime/source-union-profile.json` measures the exact real 270/302-reference
Fireball inputs against the prior union: median 3.616/4.528 ms became
0.112/0.127 ms, with the same ordered references. These are isolated CPU timings
for the union only. They remove about 3.50/4.40 ms per measured union, not the
whole 55.779/78.722 ms opening-to-visible tail. A new live run is required to
measure their actual effect; no latency or frame-target achievement is claimed.

Remaining boundary after the body import is deliberately explicit. Compiler
`Authoring.clip`, action/damage/movement/condition recipes and source provenance
still use the admitted JSON recipe documents (and the existing small native
presentation overlay). `Authoring.spell` still checks for its legacy recipe on
first uncached spell access. This change does not claim that the entire client
or every authoring recipe is native. Environment/other non-body image estimates
still inspect a PNG header on the metadata worker when their existing header
cache has no entry. Body index/category Resource deserialization remains lazy.
`CharacterGeometry.bind` still computes small scalar material-path/transform
values when an actual clip/profile binding changes; it does no image readback
or body JSON/freshness inspection.

The next compiler ownership correction is independently approved and being
implemented. Before this correction, `_actor_structure_requirements` called
`Characters.structure`, whose selector loaded full future category metadata
before the opening handoff. An isolated reveal compile was about 140 ms after
freeze removal. The source paths already exist in the admitted index; resolving
constructor identity does not require deserializing their full clip metadata.

Constructor rows now select existing revision-qualified `index.layers` paths as
`source_path`, alongside private actor layer/tint values. Required/optional media
workers explicitly admit the selected categories. `WorldPreparation._derive`
also owns explicit category/override/noise admission for its private actor-layer
output, returning the resulting immutable source snapshot and ordinary errors
before publication. Sampling uses prepared lookup-only descriptors; it must not
turn a missing handoff into a main-thread Resource load or publish an empty actor
after an admission failure. The coherent displayed owner remains until the
required preparation result is ready.

This removes full category admission from passive compiler selection and moves
any genuinely needed deserialization to its existing media/world preparation
owner. It introduces no new registry, queue, schema, prediction or validation
layer. Antislop and correctness reviewers approved the seam, and implementation
continues within the authorized three-operation plan. Source/output regressions,
the current live Gallery route and full Studio seek/loop still need to qualify
the combined change. Neither the cold cost's removal from the compiler nor the
isolated union benchmark is an achieved end-to-end latency saving until measured.

### Passive constructor selection follow-up

After the combined live route still measured door compilation at 144.94 ms and
Fireball onset at 89.78/112.64 ms, the root authorized the passive selection seam.
The independent correctness reviewer approved it with explicit row/private-layer
separation, worker error propagation and snapshot adoption requirements.
`Characters.structure` now selects revision-qualified `source_path` strings;
it no longer loads category Resources for constructor comparisons. Existing
required/optional media workers admit actual selected category data. The world
preparation worker explicitly returns `prepare_layers` success/error and its
updated immutable source snapshot; publication adopts it before native binding.
Only private visual layers carry the loaded `source_ref`. Body descriptor/sample
lookups cannot read the selector, admit an index/category or call ResourceLoader.
No importer, source schema, artwork, shader or new scheduling system was added.
Focused source qualification at that checkpoint passed 12,418 body checks, 736
fixed-rig checks across 43 rigs and 75 source-publication checks. Later full
native Studio qualification passed 8,693 checks as scoped above; the latest
expanded source fixture passes 12,424 checks. The current combined changes still
need matched live qualification, and previous onset numbers remain unmet rather
than claimed fixed. Cold category loading still exists on its appropriate
preparation worker and must be included in its nested timing. These test checks
must stay in qualification rather than being added to the production action or
sampling path.

### Action media asset admission (implemented producer boundary)

The leaf audit in `.runtime/compiler-audit-leaves-20261016/result.json` uses six
actual Gallery records in an isolated sequential compiler replay, with accepted
media/optional metadata between operations and no selected-action preview
warming. On its first Fireball, `Components.compile` took 18.804 ms inclusive;
its child `Blood.asset` took 17.672 ms across two calls. One call first loaded
the entire 2,610,696-byte `catalog/action_media_assets.json`; the second reused
that table. Later warm component compilation was under 1 ms. The blood child is
included in the component total and must not be added to it. These observations
prove a cold metadata leaf, not a live received-action latency saving or a cost
that every already-warmed cast incurs.

That table contains 13 actual assets. The selected blood definition alone is
303,909 bytes when compact JSON serialized. The reviewed change imports all 13
exact passive definitions into individual native metadata Resources within the
existing revision-qualified native source package, COW admission index and
atomic `current` marker. `SourceCatalog.asset` explicitly admits one definition
on its existing worker; `prepared_asset` is lookup-only. Compiled blood
components retain the selected definition, and WorldPreparation admits initial
authoritative residue through its existing terrain-row preparation. Blood and
SelectionMedia consume those references; renderer sampling never admits an
asset or loads the whole table. This completes the common producer boundary
rather than adding a
blood-only cache, registry, scheduler or rendering exception. Runtime performs
direct prepared-reference access and ordinary actual resource errors; schema,
identity, freshness and parity verification stay in import/fixture tests.

The newly introduced, untracked source owner/catalog scripts were renamed
to `native_presentation_sources.gd` and `native_presentation_catalog.gd` to reflect
their spell-and-action-asset scope. Their existing derived directory and cache
key remain unchanged, avoiding a separate artifact migration or runtime switch.
This changes passive metadata admission only; Factory code, artwork, shader
values, authored event order and occurrence ownership remain outside this seam.

Antislop implemented the reviewed seam and correctness reviewed the handoff and
exact-data parity after the preceding capture. The focused source/blood checks
are recorded below; a new actual live/Studio measurement must qualify the
combined implementation. No timing-target achievement is claimed from the
isolated 17.672 ms leaf measurement.

### Shared passive asset admission follow-up

A fresh six-operation Gallery compiler probe isolates the remaining first-Fireball Components cost: 18.804 ms inclusive contains 17.672 ms in Blood.asset; its first selected blood read parses the entire 2,610,696-byte catalog/action_media_assets.json. The second Fireball performs the same two blood releases with Blood.asset at 0.009 ms. Actual reveals/duration are 0.188/0.123 ms, not the blocker. First native spell Resource load is 3.919 ms and cached palette operands are 0.993 ms; neither explains the blood cost. These isolated CPU observations are not live latency acceptance.

The root and independent correctness reviewer approved extending the existing revision-qualified native presentation package with all thirteen current passive asset operands. The source owner and index are renamed to native_presentation_sources/native_presentation_catalog; the existing .derived/native-spells package and admission cache key stay in place. Each metadata-only Resource stores the exact asset identity/value, selected by an asset_metadata path in the same index. Native source paths stay immutable; the existing current marker, COW loaded shell, snapshot adoption and retained old-revision references remain the only ownership mechanism. Asset keys are explicitly namespaced from spell behavior keys. No second registry, marker, queue, texture dependency or runtime freshness proof is introduced.

The existing offline importer admits all thirteen exact legacy values and compares its saved operands offline. SourceCatalog.asset performs explicit preparation-worker admission; SourceCatalog.prepared_asset is lookup only. Blood.asset uses the selected native operand, damaging selection warms that operand, and each authoritative residue component retains its own admitted metadata reference. Initial persistent blood is admitted in WorldPreparation's existing changed/full terrain-routing loop only when actual tile residues require it; its existing source_files handoff reaches the scene owner before binding. The blood renderer borrows prepared/component refs only and never reads an asset during sampling. An actual selected asset load failure follows the ordinary preparation error result; no schema/range validation is added to action processing.

Removal obligations: the production Blood.asset and SelectionMedia whole action_media_assets document read disappear; renderer fallback admission disappears; selected data remains unchanged. Import tools/tests may retain legacy reads as exact parity oracles. At this asset-boundary checkpoint, the first door clip still parsed the 1.845 MB rigs catalog; the later rig-consumer deletion below removes that read. Fireball destruction banks still parse their selected JSON, and NativeAuthoring's existing cold overlay conversion/range checks remain. Those are separate boundaries, not silently included in the asset batch. Qualification requires exact parity for all thirteen values, lazy single-asset loading, disjoint loaded keys, immutable/COW worker handoff, retained old revisions, and real blood/replay behavior. Live onset and frame acceptance must then be measured again.

Asset-boundary qualification after import: thirty spells plus thirteen passive assets import in 173.94 ms offline, with every saved asset compared exactly before publication. Native asset metadata totals 1,242,830 bytes; selected blood is 314,318 bytes. The first isolated selected blood Resource admission measures 6.44 ms, so deserialization remains real preparation work, not a zero-cost claim. The new asset fixture passes 52 lazy-selection/COW/revision/identity checks, existing native spell admission 368, condition owners 18, concurrent/reload source ownership 83, actual blood authority/timing 281, exact Gallery blood kernels 56,881, and selected damaging/non-damaging feedback parity 27. The concurrent-index fixture also reports three ObjectDB instances at process exit; its ownership assertions pass, but that diagnostic is not described as clean. Initial persistent-residue worker integration and combined native/live qualification are being checked independently; no end-to-end target achievement follows from these isolated results.

### Yielded-prefix oracle diagnosis and continuing implementation

The later Studio failure compared a yielded native publication with
`Recording.restore(time)`, which drains later equal-time operations too. At the
actual intermediate cuts near 1683.333 and 4745.178 ms, the renderer had consumed
cursors 32 and 78; the time-only oracle expected later cursors 40 and 99. The
native probe established that the displayed states match their exact ordered
intermediate prefixes and continue draining normally. Tests must compare the
published cut's existing group/commit position, then wait for the intended
terminal prefix instead of treating the displayed clock alone as completion.
This is a test-oracle correction, not a runtime ordering defect, and introduces
no production prefix-validation pass. The corrected full native Studio run
subsequently passed 8,693 checks, with no failures, errors or warnings. That
result precedes the later native-rig/parser batch and does not establish the
remaining preparation/publication latency targets.

Concrete implementation continues under the same three-operation plan:

- The ordinary clip-uniform deletion is implemented and qualified as recorded
  below. Preserve its exact color, normal/depth inputs and material values while
  measuring the combined live path; do not describe the isolated fixture as
  achieved onset or frame performance.
- Complete advance source binding for the next received clip even when its
  actor keeps the same outfit. Source/resource readiness alone must not leave
  first-use binding work until sampling; existing preparation owns those refs
  before their cue.
- Remove the remaining preparation/publication tail using its nested measured
  work and existing owners. Already completed work can cross its handoff in the
  same host frame; real construction/draw dependencies and correct event order
  still determine publication.

The user's direction is to keep concrete implementation moving while targeted
tests and independent reviews continue, rather than retreat into repeated
evaluation or another approval cycle. Native-process coordination remains in
place. These tracks are not declared complete by source parity, an isolated
benchmark or the prefix-oracle diagnosis; the current timing targets remain
unmet until a new matched live/ordinary-scene/Studio measurement establishes
otherwise.

### Remaining rig consumer deletion

The isolated first door still parsed the 1.845 MB effective rig JSON because Authoring.clip/body, Components, ImpactPlacement, Selection and Studio looked up the legacy table even after its native admission. The approved follow-up preserves each effective clip.sheets string map in the existing BodySourceIndex.rigs instead of dropping it offline. Authoring.rigs and remaining production read-only consumers borrow that admitted rig value; Palette.prepare selects its source path from the existing index.sheets default map. No schema, texture dependency, fallback, validator or new ownership system is introduced. Import continues to use the effective native presentation overlay, preserving crouch clip overrides and source provenance. Exact forty-four rig/clip and resource-reference parity belongs to offline tests; actual six-operation compilation must neither read legacy rig JSON nor admit category Resources. Other current resource-table consumers remain explicit until migrated; this batch does not claim all recipe JSON is gone.

Rig-consumer qualification: the effective native index now preserves all 44 rigs, 454 complete clip definitions, 3,301 sheet references and 3,313 existing resource paths; 4,379 exact offline/reference checks pass, including authored CrouchIdle/CrouchRun overrides. Index size is 7,528,394 bytes; its load is still an admission/startup cost, not claimed free. The expanded six-operation source test passes 12,424 checks and asserts every compiler operation leaves category admission unchanged and never reads catalog/rigs.json. Source-publication checks remain 75 passing. Isolated compiler timings are 0.70/24.24/17.09/5.94/25.90/9.59 ms for the six records and are not an end-to-end improvement claim. Conditions.paths, condition coverage and thumbnail resource-map consumption still use the 300 KB legacy resource table; Palette's selected source lookup no longer does. Combined matched live qualification follows these source checks.

Play startup now borrows `Characters.rigs` from the same native source owner as
its worker snapshots; it does not create a separate legacy rig-table identity.
The later trusted-grammar parser switch has focused qualification as recorded
below, while its combined live qualification remains pending.
Neither that parser change nor this native-rig batch is qualified by the earlier
8,693-check native Studio run. Preserve exact token/ID and ordered packet
semantics, and report their current test/live outcome separately when measured.

### Ordinary source-clip uniform updates (implemented deletion)

`ActorConstruction.bind_source` now treats sheet and palette changes as actual
uniform-value updates through the existing SourceMaterial owner. A supported
geometry source changing to another supported clip/profile writes its final
maps and scalar values directly. It no longer clears maps/geometry flags to
null/false and restores them, or marks the unchanged quad/shader binding as
structural. Unsupported sources and incomplete profiles still clear geometry;
optional ground data, source paths/status, transforms and AABB updates retain
their existing behavior. This changes update work, not the approved source
values or rendering representation.

Two redundant producer-presence asserts were removed from SourceMaterial's
direct value/change access. Atlas output and receiver parameter-name membership
uses its existing cached dictionary instead of a linear array during changed
uniform copies. No new owner, proof scan, cache or scheduling path was added.

`tests/actor_material_preparation_checks.gd` passes 2,510 checks in
`.runtime/actor-material-preparation-checks.json`: exact actual source, receiver
and output shader uniforms, including missed acknowledgements and retained old
targets. This focused fixture makes no framebuffer or performance claim. The
subsequent full native Studio run passes 8,693 checks with zero failures, errors
or warnings, before the later native-rig/parser batch. Complete same-outfit
advance source binding and the remaining measured preparation/publication tail
remain open; current onset, publication and steady-frame targets are still unmet.

### Trusted producer parsing and host preparation priority

The existing trusted-producer parser no longer recursively qualifies JSON
syntax before decoding. Its scalar-compatibility detector selects the existing
exact decoder fallback where necessary; this does not replace the decoder or
repair a whole packet after parsing. Strict public/offline parsing retains its
grammar/depth contract. Private malformed-grammar and depth tests now exercise
that strict public boundary rather than requiring the trusted producer path to
repeat the same qualification. Exact scalar/ID and six-operation state/timeline
parity pass 3,445 checks; actual trusted SSE input passes 165 checks. Both report
no errors or warnings. These are parsing/state qualifications, not achieved
received-action latency or frame performance.

The native authoring-reload fixture passes 24 Forward+ checks. The environment
source-owner fixture passes 331 checks. Both are clean focused results; neither
replaces the unfinished combined live route or extends the earlier Studio pass
to all later changes.

The 11:31 route exposed preparation starvation rather than a script failure.
Within the same host allowance, required world/current-component preparation
now runs first, pending `hud.prepare_bar` runs next, and optional rotation media
preparation runs last. It adds no separate UI allowance or competing scheduler.
The admission fixture passes 28 checks and HUD retention passes 67. The older
recorded HUD fixture still emits its missing-portrait warning; those functional
passes are not described as warning-free.

The 11:35 matched live run completed at
`.runtime/player-runs/20261016T113552.339361Z`, with 81 checks passing and no live
script errors. Haste's pending bar finished 249.223 ms after command readiness,
versus exceeding the five-second observation window in the failed run. Door
packet-to-animation was 86.973 ms, movement 158.746 ms, Haste 35.662 ms and the two
Fireballs 85.501/100.424 ms. Fireball frame means were 14.755/19.095 ms and maxima
33.979/40.197 ms. These do **not** improve the prior 82.242/89.584 ms Fireball
onsets or meet the timing targets. The corresponding 17-layer impact frames now
perform parameter copies with no full material copies; atlas material sync was
1.114/1.108 ms, versus 2.472/2.321 ms on the earlier 34-full-copy impact frames.
This qualifies deleted material work, not an overall latency improvement.

Current Fireball nested costs remain parser/admission 6.272/4.342 ms, canonical
consumer 4.720/7.822 ms, compiler 11.393/11.514 ms, opening metadata 6.953/7.746 ms,
and opening-to-observed-animation tail 54.598/65.202 ms. Server execution is
separate at 563.206/435.125 ms. Main-thread source-role publication and waiting
still dominate the next implementation track. The run reports the existing
missing-caster-portrait warning and 32 ObjectDB/one Resource exit diagnostics;
it is not described as clean teardown or finished performance qualification.
At cleanup, two obsolete headless source-loader race reproductions from the
earlier rejected importer experiments were found still blocked (each had already
printed 191/192 failures). Their four exact Windows wrapper/child processes
were terminated. No NDClientGodot Godot process remained afterward. The live
measurement above must not be described as isolated from those headless jobs;
it remains a scoped functional/deleted-work observation, with timing targets
unmet.

Remaining source-role work is a candidate deletion of mirrored physical-role
maps and redundant count rewrites in the existing owner. A larger future-role
queue is not complete: any such continuation must retain the actual sources
pinned by worlds already being prepared, in addition to current/displayed or
projected interests. Do not report a queued-publication solution or global
completion from the parser, ownership and focused HUD checks above. Same-outfit
advance binding and the measured preparation/publication tail remain explicit
until implemented and qualified by current gameplay and Studio evidence.


### Received-operation ownership batch, 16 October afternoon

The later user request delegates reduction, opening asset resolution and
presentation compilation separately, and asks how much of the 143 KB reply is
actually consumed. The plan-adherence/ownership reviewer and compiler/correctness
reviewers remain involved. No engine/Factory edits or graphical retuning belong
to this batch.

Implemented deletions at existing ownership boundaries:

- Session packet/compiler locals now expire at their own operation handoff,
  instead of charging prior temporary destruction to the next action's setup.
- Retained reduction forks only actual mutable actor/loadout/contact collections.
  For a single audience member, its already reduced cell/contact operands feed
  presentation directly; light/hazard visibility filtering, optical/effect
  composition, public detached inputs and multi-member composition remain exact.
- The existing imported native presentation package owns 27 static fact
  descriptions and 186 recipe requirement rows across 30 spells. Runtime still
  binds occurrence-specific applicability/context. Accepted passive version/log
  payloads are retained; only mutable trace shells and pruned child lists are
  constructed. Public diagnostics remain detached.
- Opening/full source owners retain physical source selections, finite size and
  header facts, role families and completed environment unions. Required source
  header publication selects the actual source scope instead of duplicating the
  optional catalog header table. An opening no longer discards the complete
  mixed-role partitions before continuation can reuse them.
- Presenter allocation readiness and optional preparation follow an explicit
  resource-owner revision reported by existing condition/spatial/retained-tail
  updates. HP/log/ordinary motion commits still advance canonically without
  invalidating unchanged allocations. Native source completion, cue clocks,
  membership, camera and material gates remain active.

Qualification before the final finite optical-role retention correction:
source 200 and environment 345 checks; native requirement templates 373;
presentation coverage 175; exact frozen compiler output 326 checks over 51 real
operations, 289 event rows and 1,056 version rows; actual two-owner/public trace
isolation 822; resource-owner revision 25; single-member projection 39; real-six
canonical/capture ownership 59; retained transactions 225; Journal refusal/retry
31; public reducer 125; optical ownership 425. The broad snapshot harness was not
qualified against the current three-sensory/single-observer route: its fixture
requires four alternating observers. Its unchanged committed generated report
is preserved, not claimed as a current pass. Failed fixture-attempt logs remain
in `.runtime`.

Live Windows Forward+/Vulkan route
`.runtime/player-runs/20261016T125701.044401Z` passes 81 checks using actual door,
Gallery movement, Haste and native action-bar/target-click Fireballs. Warm
Fireball final framing to first observed animation is 66.710 ms, comprising
23.821 ms to opening preparation and 42.889 ms afterward. Before this frontend
batch the comparable warm values were 90.983 / 32.958 / 58.025 ms.
Warm JSON/admission is 3.952 ms, canonical admission 4.807, packet setup .005,
compiler 6.462 and opening metadata 8.326. Header count is 416 selected versus
3,235 cached; size/header publication is .396 ms versus the earlier 1.444 ms.
The Fireball segments average 14.176/13.290 ms per frame and peak at
27.406/32.668 ms. Server execution is separate at 567.683/389.943 ms. The live
harness uses one full-size SubViewport plus a root display blit; these are not
ordinary root-only or Studio timings. The live exit retains the known
missing-portrait/ObjectDB/one-Resource diagnostics, so it is not a clean teardown
claim. Full native Studio on this tree passes 8,724 checks with no errors or
warnings in `.runtime/frontend-qualified-studio.log`.

The 143,011-byte packet audit is in `.runtime/fireball-payload-audit.json`:
76,072 event bytes (including nested fact/log values), 26,290 version rows,
21,649 world updates, 13,149 root, 4,642 HUD and 1,209 envelope/separators.
The root duplicates a flat event (9.19%); changing its wire encoding belongs to
the protocol. All 207 versions/56 received event nodes, 33 world updates and
14 combat logs have current ordering/state/replay/diagnostic consumers. This
is not a claim that every field selects rendered pixels. Existing Godot native
JSON alternatives do not preserve the exact integer contract; no replacement
parser or wire-format change was introduced.

The <=30 ms onset, <=1 ms ordinary publication and <=10 ms steady-frame targets
remain unmet. Functional/oracle passes do not certify those performance targets.
The analyzer now partitions the opening-to-visible wall time into recorded
process intervals and the final draw-observation gap; inclusive CPU children
remain separately labeled rather than summed into a false exclusive total.


Final source-role correction: the existing selector retained only the current
native-optics role and discarded the other role of the same selected physical
base. That made opening/full handoffs alternate five rebuilds per warm action.
The owner now retains at most one packet per boolean role for an exact base
still selected in its current scope; both retire when that base leaves. No
cached metadata adds demand or pins by itself, and there is no base/packet cycle.
Source 203 and environment 345 checks pass cleanly, including mode reuse and
scope retirement. A corrected private causal probe isolates the prior character
cost: five packet misses, no sheet/base resolution, 15 family constructions
1.198 ms, role-map construction .643 ms and repeated finite header/size work.
The final real run confirms character preparation 1.437 ms and no repeated
packet rebuilds, rather than inferring a win from source visit counts.

Final matched live route `.runtime/player-runs/20261016T130629.163665Z` passes
81 checks. Fireball onset is 76.583/79.474 ms; warm frontend is 22.479 ms and
the subsequent process/draw-observation tail is 56.995 ms. Warm admission/decode
is 4.458 ms, canonical consumer 5.583 (reduction 4.274), packet setup .009,
compiler 6.738 and opening metadata 5.398. Metadata children are character
1.437, environment 1.033, record roles .469, size/header .431, publications
1.417 and source snapshot .068 ms. Header scope is 416 of 3,235 cached records.
Warm compiler EventTrace is 1.995 ms; full histories/logs remain present.
Compared with the pre-frontend 90.983/32.958 ms onset/frontend, this improves the
worker path but still does not meet latency or frame targets. The preceding
qualified run reached 66.710 ms onset; the final run's extra process interval
makes its end-to-end result slower despite the confirmed source work deletion.
Do not cherry-pick the preceding onset as the final-tree result or describe
these single-route measurements as a statistical speedup.

The final Fireball segments average 14.942/13.728 ms, peak 27.438/31.368 ms and
have p95 20.026/19.074 ms. Server execution is separately 613.627/443.204 ms.
The final report is `.runtime/frontend-final-role-live-analysis.json`; its
warm opening tail partitions into 13.606, 15.647 and 23.514 ms process intervals
plus 4.228 ms after the last process sample. CPU children attached to those
intervals are inclusive, not exclusive wall-time causes. No further lighting,
shader or engine change was made to improve a displayed metric.

Full native Studio after the final role-retention change passes 8,825 checks
with zero errors or warnings in `.runtime/frontend-final-role-studio.log`.
The final validation processes exit; no preview is intentionally left open.

### Opening-to-visible follow-through, 16 October

User authorized optimizing the measured 56.995 ms publication tail while server
work continues separately. This batch retains the same renderer, assets,
light values, event order and shared 2,000 us preparation allowance:

- Unchanged immutable optical observations reuse the published source
  resolution, cookies and native light nodes. Page-owner changes still reject
  stale preparations; changed/legacy optical input resolves normally. Due world
  work adopts its exact source pins before demand publication. Empty completed
  phases and existing prepared-owner readiness can finish at a spent allowance;
  actual constructors, binds, uploads and post-draw fences retain their gates.
- Required source contribution counts and physical contracts remain exact.
  Optional readiness is evaluated for queried paths rather than scanning whole
  hint catalogs. The existing union/diff skips identical source-set references,
  compares unkeyed contributions only with unkeyed references, and skips
  unchanged Boolean role publication. No second residency owner was added.
- A captured single dynamic non-batched receiver, with no removals, floor or
  support expansion and at most one captured receiver/group, runs the SAME
  passive atlas planner as one bounded scene-thread unit. An elapsed check
  precedes that work; binding/publication remains unchanged. Broader layouts
  keep their worker. Main planning CPU is separately measured; it is not added
  to world worker time.
- Pending releases no longer invalidate blood fields whose authoritative
  contributions they cannot affect. Actual flights, landing thresholds and
  field values remain unchanged. Real ordered kernel parity passes 1,100 checks;
  native blood preparation passes 32, including byte-identical 64x64 field
  pixels and zero redundant upload. That fixture reports three ObjectDB exit
  warnings; its clean functional result is not a clean teardown claim.

Source delta/union qualification passes 5,850 checks, six-operation source
selection 203, shared real-PNG residency 44, preparation admission 35 and native
receiver ownership 264. The receiver fixture compares exact single-receiver
addresses, supports, specifications and ordering against the worker planner.
Independent anti-slop and correctness/plan reviewers found no blocking issue.

First matched actual GUI route
`.runtime/player-runs/20261016T144457.063384Z` passes 81 checks. Warm onset is
64.681 ms and tail 42.988 ms. After the bounded atlas and union changes, final
route `.runtime/player-runs/20261016T145323.621572Z` also passes 81 checks:
warm onset 58.087 ms, frontend 22.953 ms and tail 35.134 ms. Compared with the
earlier final-role baseline this is about 27% less onset and 38% less tail in
these matched runs, not a statistical or 10x claim. The final tail partitions
into 7.501 and 23.054 ms process intervals plus 4.579 ms after the last sample.
The publishing interval includes only .033 ms inline atlas planning and .408 ms
blood sampling, with no blood kernel/upload work. Inclusive CPU children are
not additional elapsed intervals.

Cold first Fireball onset is 77.629 versus the baseline's 76.583 ms: no cold
improvement is claimed. Its new native resource/optical scope still has real
preparation work, and source-role publication can run twice across an opening
and its full continuation. The warm whole-action frame mean is 14.309 ms,
p95 19.687 and maximum 35.305. Therefore 100 fps/no-spike and <=30 ms onset
targets remain unmet. Server dispatch is separately 547.753/393.469 ms. No
backend changes were made. Evidence is in
`.runtime/publication-tail-final-live-analysis.json`; the actual GUI/live
measurement uses the same full-size SubViewport/display blit as the baseline.
The final live process exits but reports ObjectDB/resource teardown diagnostics.
Final native Studio seek/loop/faction/ordered-prefix qualification passes 8,862
checks with zero errors or warnings in `.runtime/publication-tail-studio.log`.
All owned validation processes exited; the final Windows process inspection
finds zero NDClientGodot Godot processes. The legacy broad SDK snapshot harness
was not rerun or newly qualified by this renderer/source batch.

### Shared reveal-publication completion — authorized 16 October

User requested a checkpoint and a common-cause fix for door, movement and spell
aftermath spikes. Starting checkpoint is `e138fc9`; source art remains ignored.
This continues operations 2/3 above, without a different renderer or backend.

Boundary: given the same accepted operation and published base, preparation
produces the exact next scene/atlas membership, materials, support contacts and
ordering operands privately. Publication adopts those prepared values once;
sampling consumes actual current actor poses/hover/time. No partial reveal,
future trace/audio, hidden-source exposure or visual retuning is allowed.

1. Finish atlas registration inside the existing bounded binding lane: prepare
   final new receiver/partition arrays and indices, group/source registration
   deltas and counts, and output/source sampling operands. Publish native array
   appends/map deltas rather than replaying GDScript row/group derivation. Avoid
   cloning the whole retained scene for ordinary sparse updates. Keep actual
   retained-node replacement commands and real capacity-growth normalization.
   Detach transferred arrays/maps from the old private retirement payload.
2. Finish scene-derived indexes in WorldPreparation: direct scenery ground
   targets and consumer deltas; prepared support-contact updates for the ground
   overlay; exact fixed order/subsequence/rank operands where that cut owns
   them. Remove the corresponding publication-time joins/reconstruction. Keep
   changing actor order and wall member selection under their existing owners.
3. Prepared static materials retain their actual prepared SourceMaterial sample
   values. Remove cross-group/material recertification at publication; ordinary
   scalar source-version/hover/visibility sampling still updates anything that
   actually changed since preparation. Dynamic/water sampling remains live.

Root owns native_light_delta; the anti-slop reviewer owns the matching atlas
source sampling change; correctness owns Play/WorldPreparation/ground overlay.
The independent plan guard also performs the anti-OOP review and checks the
whole ownership/order boundary. Native tests/profile runs are serialized.

Qualification: exact prepared-vs-original atlas addresses/group counts/order,
source changes during preparation, cancellation/retirement, support changes,
native recorded prefix/seek/loop cases, then the SAME real action route (door,
move, Haste, two Fireballs). Report per-parent phase breakdown and actual work
counts, all slow frames and idle separately. In particular, `addresses_ms`
at checkpoint included output_materials_ms; preserved-row diagnostics alone do not
prove a runtime row walk. Door actual address publication was .015 ms, while
Fireball's 1.184 ms needs its real index/buffer/upload branch distinguished.
Targets and full elapsed accounting remain unchanged; no warm-FPS or no-spike
claim follows merely from green functional tests.

### Shared reveal owner result and limits — 16 October

Checkpoint requested by the user was committed first as `e138fc9`. The new
batch completes prepared values inside the existing owners, without backend,
Factory, artwork, shader math, light tuning or event-clock changes:

- Atlas binding prepares final receiver/partition append arrays, indexes and
  output samples. Publication uses native array/map operations and ordered
  retained/group commands; zero-user/drop/reappear group identity is preserved.
- A packed floor's current row directory is its only slot authority. Removed
  eager per-receiver slot repair and duplicate per-tile scenery consumers,
  including their rotation producer. Actual projection/style/capture resolves
  the directory when needed. No every-floor search in production scenery sync.
- Actual canonical membership/order rebuilds prepare touched WorldRows indexes
  and GroundOverlay maps alongside their already prepared arrays. Publication
  adopts references. Ordinary same-membership edits remain sparse; native map
  merge replaces interpreted per-key after-value insertion. Displaced maps and
  passive completed preparation data remain under existing budgeted retirement.
- Existing light preparation now also owns colour/cookie updates and removals.
  Publication does not resynchronize every page or sample empty actor anchors.
  Actual displayed actor/fixture sampling still precedes native projection.
- Static material sample ownership replaces cross-group recertification.
  Explicit style/output fields no longer trigger empty generic uniform copying.
  Current hover/frame/water/source/binding changes keep their real consumers.
- Fixed a real prepared-to-displayed lease hole: completing movement withdrew
  152 immutable source records, then reacquired them next frame (7.031 ms plus
  5.784 ms). Terminal promotion now precedes displayed-source replacement and
  same-frame optional work, taking the latest full continuation rather than a
  cached opening-plan pointer. Exact readiness/accounting is unchanged.

The first attempted scenery/support delta still did wholesale retained-floor
registration at the cue and regressed the live route. It was rejected and
deleted, rather than accepted because isolated checks passed. The rows above
describe the corrected final ownership.

Matched real GUI route: door, move to `[26,6]`, Haste potion, Fireball `[32,8]`,
Fireball `[33,7]`; Forward+/Vulkan RTX 5090, 1600x960, view size 18, full-size
native viewport plus root display blit. Owned Godot runs were serialized. Two
final runs, with no production changes between them, each passed 81 checks:

| Action playback maximum | Earlier checkpoint route | Final run A | Unchanged repeat B |
| --- | ---: | ---: | ---: |
| Door | 47.556 ms | 69.515 ms | 44.145 ms |
| Move | 37.678 ms | 38.792 ms | 31.018 ms |
| Haste | 20.101 ms | 36.999 ms | 22.260 ms |
| First Fireball | 26.192 ms | 30.416 ms | 24.577 ms |
| Second Fireball | 35.305 ms | 38.229 ms | 29.408 ms |

These ranges do **not** establish consistent whole-frame improvement. They do
show removed work at the measured ownership boundary:

| Actual component | Instrumented during this batch, before its correction | Final repeat B |
| --- | ---: | ---: |
| Door canonical row adoption | 3.461 ms | 0.021 ms |
| Door support publication | 2.329 ms | 0.140 ms |
| Fireball scenery membership | 4.054 ms | 0.036 ms |
| Fireball floor address publication | 1.101 ms / 1,179 index writes | 0.128 ms / zero index writes |
| Door generic parameter-copy operations | 185 | 11 |
| Movement generic parameter-copy operations | 214 | 10 |

In repeat B the remaining 44.145 ms door frame has 42.103 ms player callback:
17.322 ms native lighting, 5.848 ms session/timeline, 4.131 ms world publication,
3.933 ms actor sampling, 3.317 ms ordering/output, plus source lighting, actor
membership, wall selection and optional preparation. Native lighting includes
the atlas, shadows and projection; its atlas includes resize, registry, binding,
output, material sample and culling. Do not add these children to their parents.
The door still admits 279 sources / 1,156 receiving specs, including genuine
native viewport growth and 1,098 cull checks. It is still a spike.

Repeat B has two post-action-start intervals above 33.33 ms: that door frame
and a 37.985 ms Fireball targeting interval (aim marker, before cast playback).
The targeting interval has only 12.449 ms inside the measured player callback,
unchanged pipeline counts and no world publication. Its remaining interval is
not attributed to a particular input/native/OS cause by this instrumentation.
Run A additionally has 57.597 ms during targeting, 38.792 ms movement,
36.999 ms Haste, and 38.229 ms Fireball aftermath. No no-spike or 100-FPS claim.

Packet-to-first-visible Fireball is 70.002/60.019 ms in A and 67.398/61.186 ms in
B (first/repeated). B's opening preparation is 26.008/22.183 ms; the remaining
41.390/39.003 ms includes actual process intervals, prepared-world gates and the
draw observation. Server dispatch remains separate: 713.336/446.097 ms in A,
624.248/422.646 ms in B. This batch does not solve those server times or claim
an improvement in repeated-cast onset.

Evidence: `.runtime/player-runs/20261016T154109.508036Z` and
`20261016T154406.286364Z`; `.runtime/shared-reveal-final-live-analysis.json` and
`shared-reveal-final-repeat-live-analysis.json`; complete frame profiles
`generated/profiles/2026-10-16T17-41-40-gallery-live-spells.json` and
`2026-10-16T17-44-35-gallery-live-spells.json`. Raw CPU/context diagnostics retain
the actual work counts and nested stage decomposition, not only an FPS summary.

Correctness qualification: source output samples 159 headless / 204 native;
staged atlas 1,987; native lifecycle 221; prepared emitters 69 headless / 79
native plus 17 ownership checks; ground support 67; scenery 10; prepared
admission 28; sparse preparation 69; actor material/retirement 3,726; world
projection 147; native floor/rotation 28; native HUD grid 241; terminal lease
handoff 8; final native WorldPreparation/atlas 150 (nine cases). Output, staged, emitter and terrain suites include at least 85 exact
native framebuffer comparisons. Final full native Studio passes 8,647 checks
covering seek/loop/faction selection and exact ordered prefixes. Its count varies
with sampled playback frames; it is not a fixed test inventory count.

The old `media_completion_checks` fixture was attempted but has stale null-sense
and missing native-render-owner assumptions before reaching the new regression;
it was restored unchanged, not reported green. The new narrow terminal handoff
fixture proves CPU registration continuity; real playback remains qualified by
the live and Studio runs. Sparse preparation retains 26 ObjectDB exit warnings;
final live runs retain 30/31 leaked-instance warnings and one resource-at-exit
diagnostic, plus the missing generic-caster portrait warning. Native Studio and
the focused native output suites are clean. No clean-live-teardown claim.

The anti-slop/correctness reviewers and independent plan/anti-OOP guard found no
remaining blocker in these saved ownership changes. Broader latency/frame
targets remain open. All owned client Godot processes were closed after testing.

### Door reveal investigation and next operations — 16 October

User requested the door reveal's nested breakdown and which work can move off
its critical path. This section records read-only investigation of the two
already qualified live runs above. No new production changes, Godot runs or
performance qualification are implied. Anti-slop, correctness and the independent
plan/anti-OOP guard participated in this investigation. The anti-slop and
plan/anti-OOP reviewers approved the execution order below, with the capacity
atomicity and intended published visibility requirements recorded explicitly.

The door changes 21 to 1,003 placements, 38 to 317 draw entries, and one to six
actors. Both repeats perform the same work: 279 atlas sources, 1,156 receiver
specifications, 292 group commands and 1,098 static cull checks. These are work
counts, not counts of independently loaded character sheets. Slower repeat A
takes longer across most CPU stages, rather than exposing a different large
operation. Use repeat B frame 7720 for the following disjoint accounting:

| Player callback phase | CPU ms |
| --- | ---: |
| Session/timeline | 5.848 |
| World publication | 4.131 |
| Actor membership | 1.519 |
| Actor/component sampling | 3.933 |
| Scenery/fixture/source-light sampling | 3.037 |
| Wall visibility | 1.162 |
| Native lighting | 17.322 |
| Draw order/output | 3.317 |
| Interaction | 0.090 |
| Outside the named callback stages | 1.744 |
| **Player callback** | **42.103** |
| **Whole process interval** | **44.145** |

The other 2.042 ms of the interval is outside this callback, not established
server or GPU time. Ordinary post-reveal median player CPU is 6.801 ms. Repeat A
has 67.187 ms player CPU / 69.515 ms interval. Neither is an achieved frame target.

Native lighting's 17.322 ms contains atlas 13.916, modular shadows 3.105,
source projection .292 and .009 wrapper overhead. The atlas contains reconcile
8.635, material sampling 2.502, projection/culling 2.559, style .074 and .146
setup/other. Reconcile contains capacity growth 2.188, source/support registry
1.327, bulk binding 3.212, output adoption/transport 1.237, address normalization
.206, and .465 specification/setup/other. Children are not additional costs.
Bulk binding includes native directory/array publication 1.026, ordered group
registration 1.233 and source-directory transfer .580; its remaining .373 is
style merge, ordered replacements and overhead. The material pass contains 108
actual actor UV copies and 119 uniform writes; its full cost is not redundant.

Readiness is a separate problem from the publication frame. In repeat B the
packet completes 143.272 ms after click; first door-action animation is observed
at 227.522 ms. Media readiness becomes true at 794.975 ms, then the world gate
holds until the 1,393.921 ms observation: about 599 ms. The reveal frame's ending
stamp is 1,379.919 ms after click; the next observation sees the released gate.
These clocks describe scheduling/observation, not 599 ms of continuous CPU work.

The actor-preparation phase spans 65 sampled frames / 453.019 ms, but consumes
29.014 ms charged world CPU, including 19.808 ms native preparation. For 31 of
those frames, Play._step_world_preparation rejects all native preparation because
the whole environment cut is not resident, although actor construction can have
different dependencies. Those frames leave 36.619 ms of the existing shared
allowance unused. There is no per-layer or per-actor draw fence in these actor
and disabled shadow constructors. Once attempted, a missing actor layer becomes
unbound_entry and prevents later actors from being attempted. Existing profiling
does not identify the exact blocking actor/slot/source in every waiting frame.

Implement in this order within the existing owners and 2 ms shared budget:

1. **Overlap ready construction with source residency.** Replace the blanket
   environment prerequisite for all native phases with each phase's actual
   required operands. Let ready actor graphs/layers/shadow structures and other
   independent work proceed; defer only the entries whose sources are absent.
   Reuse the existing preparation cursors/work ownership, not a second scheduler.
   Keep the complete media/world publication gate and the currently displayed
   event prefix. Add only diagnostic actor/slot/missing-source status to identify
   the remaining producer stall. The measured unused allowance is an overlap
   opportunity, not a promised 453 ms or 599 ms saving.
2. **Adopt remaining prepared indexes and constants.** Prepare actual retained
   scenery style writes instead of revisiting newly private sprites/full floor
   packets whose visibility is already correct (the current scenery pass is
   2.616 ms). Carry the residue-index delta with worker-produced tile results
   instead of scanning canonical tiles during BloodRenderer sampling (.839 ms
   despite no active blood). Adopt resolved actor member rows rather than six
   Characters.resolve calls (.496 ms). Retain prepared clip/source/material
   constants instead of revalidating five outfits (.551 ms); actual frame,
   facing, pose, hover and condition-clock changes still sample normally.
   These are measured candidate scopes, not a claim that every parent phase
   disappears. Ordinary sparse updates must remain proportional to changes.
3. **Reserve exact atlas capacity before final binding.** The worker already
   computes next_height. At the existing post-plan/pre-bind owner boundary,
   reserve that exact append-only height and coherently normalize CURRENT output
   regions in one non-yielding step after the existing stale-base check, leaving
   integer addresses/membership/source order
   and event clocks unchanged. Explicitly rebase this candidate's capacity token;
   other prepared candidates remain invalidated normally. Cancellation retains
   the reserved physical capacity, not the old height. This is a capacity-only
   exception to private preparation, requiring exact old-frame pixel equality.
   It moves about 2.188 + .187 ms earlier, rather than deleting the work. Report
   the native indivisible overrun and any effect on readiness; do not increase
   the budget or reserve a blanket maximum.
4. **Finish static atlas publication operands.** Prepare screen intersections
   for the captured camera/visibility, and skip redundant visibility rechecks
   for known-hidden new receivers while preserving their admitted membership;
   at least 763 of the 1,098 static cull visits end hidden. Retain the existing
   fallback when camera/ancestor visibility changes. Use intended published
   ancestor visibility, not the deliberately hidden preparation parent. The
   2.559 ms phase includes
   dynamic projection and native visibility writes, so it is only a ceiling.
   Batch new-group registration within the existing ordered runs, retaining
   zero-user/drop/reappear identity and retained-node operations. Keep displaced
   preparation directories in existing budgeted retirement to avoid destroying
   them during source-directory transfer. Native array/map appends already cost
   1.026 ms and are real publication work; a worker cannot mutate live ownership
   to make them free. Do not introduce an O(N) clone for ordinary K changes.

Prepare passive derivation on workers; prepare native resources earlier under
their scene-thread owner. Active SceneTree/material/viewport changes must not be
moved to arbitrary workers. Shadows already create zero new actors/casters/meshes
at this cue, but still sample 55 casters and 25 lights: their 3.105 ms includes
snapshots .482, layout .742, sources .441, updates 1.249 and other .191. Stable
operands may be retained; current source/pose/light updates remain live.

Before attributing remaining costs, split the existing timeline_advance timer
(3.968 ms, including readiness callbacks and ordered commit/trace work), and the
1.744 ms outside named callback stages. No additional runtime asset/schema
validation or broad instrumentation framework is required.

The worker diagnostic is cumulative 141.305 ms, including the 18.748 ms atlas
planner and initial world derivation/static sorting. It is not a decomposition
of the 599 ms scheduling hold and is not added to the publication frame. Initial
derivation still lacks separate row/support/visibility/geometry/actor-binding
timers; collect these existing-worker phase timings with the next live route
before attributing or attempting to optimize the remainder.

Qualification for this continuation: unchanged event hierarchy/prefix and actual
animation clocks; prepared versus displayed scenery/residue/actor membership;
exact atlas address/group/order values; old pixels during capacity reservation,
cancellation and rejection of other stale candidates; camera change during
preparation; all four views; existing seek/loop coverage; then the same real door,
move, Haste and two-Fireball route. Report preparation CPU, unused allowance,
time held at each gate and the actual publication-frame subphases separately.
Preserve the approved shaders, light cap, art and final framebuffer. No new
performance result has been measured for these proposed operations.

### Door preparation/publication implementation — 16 October

The user authorized all four operations, reviewers and a fresh complete live
route. The saved implementation stays in Play, Timeline diagnostics,
WorldPreparation, BloodRenderer and the existing native atlas/delta owners.
No backend, Factory, shader, light tuning, asset or UI change was made.

- Native construction now checks the actual operands of each actor layer,
  object or ground batch. Missing sources remain owned, while other actors,
  layers and environment rows progress through existing cursors. Completed-lane
  counts and deadlines bound retries. Actors cannot be taken before their exact
  sources and prepared shadows complete. The final complete media/world gate is
  retained before any event/clock/state publication.
- Scene publication adopts resolved actor rows and exact prepared outfit and
  immutable neutral material operands. Live facing, frame, condition material
  and pose still sample the actual displayed clock. Scenery applies prepared
  retained style writes, while private/full floor buffers and CPU visibility
  values transfer together. Sparse geometry retains explicit visibility writes.
  The canonical blood index transfers with its exact tile owner/revision.
- The post-plan/pre-bind capacity step reserves only the proven required atlas
  height, atomically normalizes current outputs and rebases only that candidate.
  Cancellation keeps reserved capacity. Other old candidates remain stale.
- Static receiving rows prepare camera intersections using intended published
  ancestry. Cue-time camera/source-visibility changes take the ordinary current
  path. Known-hidden rows remain admitted but skip redundant cull visits.
  Ordered private-group spans use native directory merges; retained replacement
  barriers preserve zero-user/drop/reappear semantics. Replaced private receiver
  directories remain under existing budgeted retirement.

Review found and closed two production issues before final qualification:
completed construction lanes must return without full empty rescans, and sparse
ground geometry packets do not own visibility channels. Focused fixture setup
also initially omitted actual source/membership operands and a group join-mask
and changed-row precondition; those fixtures were corrected, not covered with
production defaults or accepted with ScriptErrors.

The first complete live run exposed an actual priority inversion: ready decoded
required images waited while hidden constructors took almost the whole 2 ms
allowance. There were 19 such frames versus one in the baseline. The final order
is passive worker adoption/exact source pins, demand publication, required media
uploads, then native preparation using the remaining SAME allowance. A separate
zero-budget correction keeps membership construction below the elapsed guard.
Neither change introduces another queue, owner, allowance or publication path.

Functional/graphics evidence before that final scheduling-only correction:
Timeline precision 5 and delayed world/event-prefix comparisons 6,812; scenery
10; overlap 15; sparse preparation/residue index 78; staged atlas 1,987 with 53
exact native pairs; WorldPreparation/atlas 150 with 9 exact native pairs; focused
capacity/cull/group tests 105 headless / 144 native with 13 exact native pairs;
native Studio seek/loop/faction/event-prefix checks 8,830. Thus at least 75 native
framebuffer pairs are byte-exact, including current old-frame pixels during
reservation and cancellation. After the final scheduling correction, admission
35 and another complete real GUI route 81 pass. Sparse preparation retains its
26 pre-existing ObjectDB exit warnings; live teardown still reports leaked
instances and one resource at exit. No clean-live-teardown claim.

Final matched live route remains door, move `[26,6]`, Haste, Fireball `[32,8]`,
Fireball `[33,7]`, using Forward+/Vulkan 1600x960/view 18 and the same full-size
native viewport/display blit. Both final runs pass 81 checks. The Factory's own
preview was present; no GPU isolation or cause for general timing variation is
claimed. Owned native runs were serialized. Compare the faster saved baseline B
with both final runs, rather than selecting only the fastest new result:

| Metric | Baseline B | Final A | Unchanged final B |
| --- | ---: | ---: | ---: |
| Door media hold | 344.108 ms | 357.605 ms | 321.182 ms |
| Door world hold | 598.946 ms | 402.020 ms | 427.948 ms |
| Door combined observed holds | 943.054 ms | 759.625 ms | 749.130 ms |
| Door publication interval | 44.145 ms | 30.455 ms | 32.484 ms |
| Door player CPU | 42.103 ms | 28.718 ms | 30.741 ms |
| Door publication after click | 1379.919 ms | 1224.497 ms | 1181.029 ms |
| Movement playback maximum | 31.018 ms | 28.367 ms | 31.962 ms |
| Movement combined observed holds | 304.363 ms | 334.183 ms | 316.080 ms |
| Haste playback maximum | 22.260 ms | 23.504 ms | 22.196 ms |
| First Fireball playback maximum | 24.577 ms | 24.643 ms | 30.475 ms |
| Second Fireball playback maximum | 29.408 ms | 31.364 ms | 34.006 ms |
| First Fireball packet-to-animation | 67.398 ms | 60.200 ms | 72.855 ms |
| Second Fireball packet-to-animation | 61.186 ms | 56.829 ms | 82.252 ms |
| Idle same-view interval median | 11.324 ms | 8.730 ms | 12.026 ms |
| Idle same-view interval p95 | 15.470 ms | 15.005 ms | 17.809 ms |

The door wins hold across both final repeats: combined observed holds improve
19-21%, and its publication interval improves 26-31%. Media/world holds are
sampled phase transitions, not CPU durations. This does NOT establish improved
movement readiness, Fireball response or steady scene FPS: those remain mixed.
The earlier unchanged baseline A had a 69.515 ms door frame and larger other
action maxima; it remains evidence of variation, not a denominator for a larger
claimed gain.

Final A door carries the same 1,003 placements / 317 draws / 6 actors, 279 atlas sources,
1,156 specs and 54 actual UV changes. Scenery 2.616->.058 ms, actor resolution .496->.028,
outfit residency .551->.037 and blood index .839->.001. Atlas 13.916->8.302 ms;
growth and old-output normalization leave the cue, while their earlier native
step is charged (the initial implementation run measured 1.632 ms capacity work,
2.051 ms total shared allowance used, a .051 ms indivisible overrun). Static live
cull checks 1,098->261: 1,098 prepared decisions include 837 hidden rows. Their admitted
membership remains intact. Registry/output/material/current UV work remains real.

Do not hide the other spikes behind the door result. Final A has a 39.479 ms
first-Fireball targeting interval BEFORE submission; its player callback is
only part of that interval and the remaining input/native time is not attributed
by this instrumentation. Final B has a 34.006 ms repeated-Fireball aftermath.
An earlier new run's 32.940 ms aftermath decomposes mostly to shadow target
resize: 1.309->4.264 ms with unchanged caster counts/target pixels; the final
runs' same leaf is .866/1.007 ms, so it is not the cause of every later frame.
Final B's repeated onset 82.252 ms is 22.801 ms opening preparation plus 59.451 ms
tail (process intervals 3.283+17.406+16.348+18.679, then 3.735 ms observation gap).
Those intervals include real native preparation/sampling waits and slower
ordinary frames; no new server delay is hidden inside that client metric.
Server Fireball dispatch is separately 553.181/401.681 ms in final A and
615.507/442.546 ms in final B. No no-spike or 100+fps claim; this completes the
four scoped door operations, not every performance target in the parent plan.

Evidence: final runs `.runtime/player-runs/20261016T163627.778509Z` and
`20261016T163953.360043Z`, analyses `.runtime/door-four-priority-live-analysis.json`
and `.runtime/door-four-final-repeat-analysis.json`, compact comparison
`.runtime/door-four-results.json`. The first two implementation runs
`20261016T162932.670629Z` and `20261016T163112.743822Z` also pass 81 checks and expose
the upload priority inversion. Run `20261016T163822.246103Z` is not used for timing
comparison because a concurrent owned CPU-analysis loop occupied a core; that
analysis was stopped and the clean final repeat collected afterward.

Final seek qualification found and fixed a zero-budget polling deadlock in the
blood resource owner. A passive `prepare_resources(0)` poll marked the frame's
page-constructor allowance as consumed before doing any construction; the later
funded call in that same frame then refused to run. A reused replay installation
could repeat this forever despite all source assets being ready. The owner now
sets that marker only after budget and constructor admission succeed. No clock,
event, shader or publication gate was changed. The new real Forward+ regression
passes 20 checks, including same-frame zero-to-positive allowance, one actual
page per frame and real post-draw readiness. The fresh complete native Studio
suite passes 8,878 checks with zero failures after this correction. The timing
table above precedes this final stamp-only liveness fix; a final live route is
recorded below separately.

Final qualified route `20261016T165408.501605Z` passes all 81 checks with the
stamp correction in place. Door media/world holds are 306.073/399.536 ms,
705.609 ms combined (25.2% below baseline B); publication is 30.292 ms with
28.527 ms player CPU (31.4% below the baseline frame interval), 1114.253 ms
after click. This supports the repeatable door improvement without selecting
only this fastest wait result. The Factory preview was present during earlier
captures; no Godot process remained at the final process audit.

Later live measurements from that same final route:

| Metric | Baseline B | Final qualified route |
| --- | ---: | ---: |
| Movement combined observed holds | 304.363 ms | 400.445 ms |
| Movement playback maximum | 31.018 ms | 28.907 ms |
| Haste playback maximum | 22.260 ms | 23.458 ms |
| First Fireball playback maximum | 24.577 ms | 25.332 ms |
| Second Fireball playback maximum | 29.408 ms | 27.704 ms |
| First Fireball packet-to-animation | 67.398 ms | 63.941 ms |
| Second Fireball packet-to-animation | 61.186 ms | 77.449 ms |
| Idle same-view interval median | 11.324 ms | 9.696 ms |
| Idle same-view interval p95 | 15.470 ms | 15.360 ms |

First/repeated Fireball server execution is separately 635.296/442.760 ms.
First Fireball observed media/world holds are 39.305/44.762 ms; repeated holds
16.449/23.496 ms. These occur across playback cuts and are not added to the
packet-to-first-animation metric. Movement's larger final wait and the variable
spell results remain open limits; the four door operations are complete, but
this is not evidence that the parent plan's whole-scene frame/latency targets
have all been met. No additional production changes were made in response to
that timing variation. Final analysis is
`.runtime/door-four-final-qualified-analysis.json`, also included in
`.runtime/door-four-results.json`. The live route retains the existing missing
generic-caster portrait warning, 30 leaked ObjectDB instances and one resource
still in use at exit; the native Studio suite has zero failures. Final read-only
plan/ownership/correctness review found no actionable blocker.

### Reveal latency continuation — 16 October, target below 50 ms

The user explicitly rejected the remaining 706 ms door and 400 ms movement
readiness waits. Target each below 50 ms, with below 100 ms the minimum; do not
trade these for worse Fireball, scene frame times, event ordering or pixels.
The current four-operation commit is `461bd07`. The unchanged previous commit
has a 943 ms door wait but a smaller 304 ms movement wait; therefore the last
change improved the door but does not qualify as a general latency improvement.
Both saved Fireball readiness holds also increased. All are acceptance paths.

Boundary/input/output: the same actual GUI Gallery door, movement to `[26,6]`,
Haste and two Fireballs; all client readiness holds and native frames are
observed independently from server execution and authored animation duration.
The complete decomposition is `.runtime/reveal_wait_decomposition.md/.json`.
Door media/world holds are 306.073/399.536 ms; movement 76.259/324.186 ms.
After construction, atlas receiver/capture/bind lanes cost respectively
73.242/11.365/28.318 ms for the door and 40.948/9.575/15.554 ms for movement.
These are actual scene-thread elapsed totals spread across 53/32 frames with
effectively no remaining shared allowance. Worker derivation and frame wall
times overlap and must not be added to those CPU totals.

Implementation order within existing owners:

1. Remove provisional per-row atlas construction before the planner. Capture
   each source once, compute the final static spec/support mask and numeric
   projection from immutable source/geometry operands in the existing planner
   worker, then create each hidden native receiver exactly once from that
   final packet. Dynamic sampling remains under its scene-thread owner. Keep
   exact group/rank/row order, stale-base rejection, cancellation and final
   all-or-nothing publication. Measure real source/material/node/projection
   leaf work; do not call every old millisecond deleted.
2. Give the next already-received cut's existing preparation owner useful
   preceding-animation time after current required effects and source uploads.
   Inspect missing-source retries and full-set scans before adding work to
   this priority. Keep one shared allowance; do not increase it to hide waits.
   Do not prepare later world cuts against an uncommitted predecessor's base.
3. Audit the exact selected-view source closure. The all-four-view environment
   metadata is known, but the saved trace cannot prove which paths were unused
   because different object orientations share those paths. Record exact
   current-view dependencies from existing worker results. Remove unused-view
   readiness only if the selected world/rotation owner proves the complete
   required closure; do not weaken the gate using filename heuristics.
4. Decompose and delete the remaining critical work identified by those
   measurements until both readiness targets are qualified. Preserve source
   sharing by actual sheet/binding identity, current-frame required effect
   priority, bounded retirement and existing worker/scene ownership. No new
   broad scheduler, runtime validators, graphics, backend or Factory changes.

Material cloning was measured and rejected before production: on actual shader
pairs `ShaderMaterial.duplicate(false)` plus shader reassignment is slower than
the existing explicit copy and has a flame texture operand mismatch. It is not
an assumed optimization. Anti-slop/correctness and the independent plan/anti-OOP
guard stay involved. Qualification requires focused value/pixel/cancellation
checks, seek/loop checks for changed ownership, repeated live complete routes,
and explicit reporting of every known uncovered or regressed path. Do not stop
at a fast final publication frame while playback still waits hundreds of ms.

The next measured implementation within operation 4 is bounded by the same
owners. Finite PNG batches may hand off each completed private image through a
mutex mailbox while retaining their worker slot until task completion; caller
publication and exact CPU/fixture roles remain the readiness boundary. Static
native receivers may use explicit RenderingServer canvas RID ownership instead
of Sprite2D Nodes, with worker-created items hidden and unparented until the
scene thread adopts them. The installed Safe threading mode and Forward+/Vulkan
API were verified without changing renderer settings. The isolated native
probe passes 78 checks and 21 byte-exact received-cell/final-3D pixel pairs,
including cancellation and a parent closed before adoption. This proves
correctness and a small measured construction saving, not the entire latency
target.

One passive static forecast may cross an already-proven source-only boundary.
It stops at the next world, actor-structure or staged-support boundary and may
derive only static operands against the unchanged published static base. Actor
membership, bindings, geometry and optical owners must be recaptured at normal
eligibility after the source cut. No second scene preparation graph or general
queue is introduced. Epoch/view/base changes discard the forecast after its
worker completes; unfinished tasks are never joined in the rendering callback.

The completed-image queue clocks then identified 221–237 ms dispatch waits for
revealed actor sheets behind scenery, with only 3.5–14 ms actual decode/upload.
Keep current source requirements urgent first; after those are ready, promote
the earliest received actor closure, then its environment closure. All keep
their existing strong leases and required priority. This is the existing media
owner's priority rule, not another queue or weaker readiness gate.

The next trace also measures 35–36 ms per torch animation frame recomputing
immutable optical moments, across sixteen originals. Bake those exact energy
and emission-centroid values with the original reducer into a metadata-only
native binary Resource and pass its matching record with the decode request.
Unknown/new fixture paths keep the original worker calculation. Source rebuild
refreshes the resource; no runtime freshness/hash scan. Binary serialization
is required here because the text resource rounds normalized optical values.
Qualification compares all original pixels, moments, animated heights and
normalized energy values after a fresh saved-resource load.

Current door data leaves the construction boundary explicit: source Nodes were
entering the hidden active tree before their uniforms/geometry were ready, but
the isolated delayed-attach/material experiment saved only about 0.5–1.2 ms per
200 draws. Do not ship that as the solution. Extract the shared authored
environment descriptor (selected record, quad, numeric bounds/transforms and
uniform operands) into passive worker preparation. One finite existing world
resource task creates private materials/meshes from captured Texture references;
the scene owner creates/adopts rendering Nodes. Water/flame clock registration
stays with its scene owner. Do not instantiate rendering Nodes on workers under
the installed Safe threading mode. Preserve the shared constructor algorithm,
not a parallel renderer-specific copy of it.

Completed source handles also need bounded progress during native construction:
when current requirements are ready and the native worker-upload path has a
pending world, permit one completed texture/facts adoption before construction
using the same frame allowance. Otherwise four completed decode batches can
hold all producer slots until the optional publication lane gets time. No new
queue, readiness shortcut or extra allowance is introduced.

Static output materials likewise use the existing atlas planner worker. Its
scene capture supplies the exact compatible source uniforms, quad size, native
target shader and strong receiving-texture reference. The worker creates only
that private material; dynamic actor/flame treatment and final output-region
binding retain their existing owners. The shared source/output compatibility
selection remains one helper, and first-draw pixel comparisons qualify this
deferred path before gameplay measurement.

### Final render packet continuation — 16 October

The latest actual route, `20261016T191624.664159Z`, regressed to about 664 ms
door readiness and 286 ms movement readiness. The door preparation window
(frames 11594–11709) spans 833 ms and charges 253 ms to the shared account:
129 ms in world preparation and 106 ms in media handoff. These are observed
scene-thread phase totals, not worker CPU or extra latency to add to the holds.
Small setter changes cannot close this gap. Keep the 2 ms shared allowance;
remove accidental work and serial dependencies from that account.

1. The existing authored environment descriptor produces the final static draw
   operands: source, receiver and capped-output parameters, numeric geometry,
   transforms, bounds and texture paths. The existing atlas planner completes
   support masks, layout and ordered group commands from those operands. Do
   not construct a source material and enumerate its uniforms back into two
   target copies. The existing WorldPreparation owner retains this one final
   render packet; no additional renderer, scheduler or registry is introduced.
2. Physical source admission owns shared immutable originals and optical facts
   once. Descriptor/layout preparation starts before all textures are resident;
   private resource realization receives the exact strong Texture references
   as they become available. Missing texture residency must not postpone the
   independent numeric work. Actor layer/clip facts may be shared, while each
   occurrence's mutable material, clocks and native outputs remain private.
3. Completed media-handle receipt is independent of optional-library family
   enumeration and selection maintenance. Keep the existing bounded producer
   slots, roles, pins, priority and actual publication boundary. Current required
   work remains first; optional maintenance cannot repeatedly consume the same
   allowance merely to expose an already completed handle.
4. The scene thread supplies actual IDs and parents, creates/adopts Nodes and
   animation graphs, and publishes the already prepared packet at its ordered
   cue. Private resources and passive commands are prepared under their existing
   owners. Live Node/Resource mutation never crosses into a worker. Epoch,
   quarter, static-base, support and source ownership gates remain; canceled
   private work retires through the existing bounded lifetime path.

Charge every handoff, constructor and indivisible overrun to the actual account;
do not replace the limit with a larger fixed allowance. Qualification must show
where the old source/capture/constructor work disappeared, which work remains
on the scene thread, and the received-packet-to-ready critical path. The target
remains below 50 ms, with below 100 ms the minimum, for both door and movement
without Fireball or whole-scene regressions. Frozen descriptor/uniform and native
pixel comparisons, cancellation/source-role tests, Studio seeking/looping and
repeated complete live routes qualify the change. No guaranteed 10× claim,
graphics/backend change, runtime validator or new approval step is implied.
Anti-slop, correctness and the independent plan/anti-OOP reviewers remain active.

The combined actor breakdown now measures 47.977 ms in actor derivation, of
which four actual category `ResourceLoader.CACHE_REUSE` calls consume 44.068 ms.
That duration may include native cache/load contention; it is not attributed to
disk alone. The remaining actor derivation is below 4 ms. Implement the next
whole source boundary: a thin category Resource owns shared clip paths, headers
and optional-library source summaries; a lazy native Resource per selected clip
owns its exact geometry, optical/socket and role facts. Both stay in the existing
revision-qualified body package, index, COW admission shell and atomic current
marker. Required media/world workers admit the selected clip; sampling performs
lookup only. Optional all-clip discovery reads summaries without admitting heavy
clip records. Actor IDs do not select or duplicate these physical facts, and
actor layer path maps borrow the shared category value. Preserve every existing
source selection, role, header, geometry and socket value; qualify all imported
clips/components, retained old revisions and actual live/Studio behavior before
claiming the readiness target. No permanent second format, runtime schema/hash
validation or artwork change is introduced. Correctness and anti-slop review
remain active while the independent guard implements this bounded source seam.

Static receiver adoption may group the planner's private canvas RIDs beneath
one hidden identity-transform canvas RID. Each draw retains the batch owner;
the batch retains no child directory. Workers never borrow the live parent.
The scene owner attaches that single parent and publishes its visibility at the
ordered cue; individual ranks, visibility/culling and changed-camera fallback
remain exact. Existing source-directory adoption runs once per source, while
only real dynamic Nodes retain the per-receiver constructor lane. The last draw
owns batch lifetime and cancellation uses existing retirement. This changes the
actual main-thread unit rather than adding a queue or increasing its allowance;
mixed static/dynamic, group-order and first-draw pixel tests must qualify it.

Thin body metadata is generated at revision `1792180196-344028`; artwork is
unchanged. Frozen previous native Resources versus all new clip facts pass
70,213 checks (269 categories including accents, 3,333 clips, 3,461 slot records).
The actual six-record legacy body comparison passes 14,419 checks; source
ownership 203, actor material/geometry 3,726 and overlap 16 also pass without
script errors or warnings. NakedBody category metadata is 53,691 bytes plus
37,017 for selected Idle, versus the previous 590,590-byte whole category;
Head10 is 73,656 plus 73,372 versus 1,144,516. These are serialized size and
semantic results, not a live timing or framebuffer claim. The next combined
route must distinguish category and clip native-load time and retain all
Fireball, scene and Studio qualification requirements above.

The combined route `20261016T200318.764194Z` still fails acceptance: door
421.703 ms (27.273 media, 394.430 world); movement 109.345 ms media with zero
world hold. Thin actor derivation is now 3.353 ms, while actual actor scene work
is 30.179 ms, including 10.556 ms atlas source setup, 5.938 ms source binding,
5.642 ms layer creation, 3.099 ms graph and 2.537 ms shadow preparation. The next
bounded packet seam builds private actor materials/quad/receiving/output Resources
under one finite WorldPreparation task, independent of the environment PNG
closure. The shared source/geometry algorithms remain the sole value owners.
Scene Nodes, graphs, live pose/UV/condition deltas, optical support and shadows
stay on main. Missing selected texture uniforms finalize once before admission;
retained layers remain binding-only. Same epoch/cancellation/retirement owner;
no additional producer queue or runtime validator. Anti-slop and the independent
plan/anti-OOP guard review the implementation; first visible changed-UV and
actual-condition pixels must qualify it before another combined live route.

The same movement trace identifies Head22 Run normals queued only 156 ms after
click, then 32 ms dispatch wait, 21 ms intra-batch wait and 14 ms decode/upload.
Selection hints currently consult body-action recipes, while locomotion is
authored through movement contexts. Reuse the existing finite encounter movement
clip closure plus the selected condition movement pose when an actual movement
choice is offered. These remain optional disclosed-source candidates with the
existing budget/roles and onset priority; no predicted event or state is created.
Real recorded walking/normal source coverage fails before this correction and
passes afterward. This does not itself establish the live latency target.

### Complete the dependency chain, rather than isolated counters

The 20:27 actual route still fails: door 427.927 ms, movement 16.316 ms.
The door charges 99.645 ms of world preparation and 13.125 ms of source receipt
across 60 frames. Its atlas worker starts only after object construction,
membership, scenery and order complete. That serial chain, and source admission
waits over 200 ms for roughly 1 ms PNG work, must change; faster individual
constructors are not the acceptance criterion.

- Rebalance the existing maximum 16 private images from four required jobs of
  four images to eight required jobs of two. Optional-only work remains at most
  four single-image jobs. Partly consumed unfinished jobs retain their slots.
  Receipt may consume up to 16 already prepared pointers rather than the former
  eight-upload count, but both real 2 ms guards remain. This changes producer
  granularity, not capacity or the host allowance. Mixed saturation, cancellation,
  role and exact-image checks qualify it; no speedup is inferred from constants.
- The one environment resource task consumes finite batches of resident rows.
  An unrelated missing image cannot block another row's resources. Each task
  has private input/result dictionaries, joins before transferring a complete
  row, and finishes before the next task starts. Completed rows may adopt while
  a later batch is running. Original canonical membership and atlas job order,
  full source pins and the final all-row publication gate remain unchanged.
- Keep missing currently displayed/onset sources strictly first. After that
  actual closure is ready, the exact next-cut actor and environment producers
  share urgency. Delete the second actor-readiness fence that withheld room
  source priority until all future actor CPU/GPU roles were published: those
  producers are independent. Equal-urgency source FIFO and every existing role,
  pin, cancellation and final publication gate remain. Neither a later animation
  nor another camera view becomes urgent merely by existing in the operation.
- Complete private atlas source directories, output uniforms and region values
  on the existing planner worker using captured scalar identities and numeric
  operands. The scene thread still owns Nodes, dynamic receiver attachment,
  live output installation/acknowledgement and uncaptured retained-source
  fallbacks. Private shells belong exclusively to the worker until it joins.
- Decouple atlas input readiness from unrelated final graph/shadow/membership
  construction. Reuse one atlas candidate and the exact canonical source/row
  sequence; completion order or native IDs must never select painter/group
  order. Only actual source identity/material/crop/visibility/support operands
  delay capture. Scene resources, optical roles and atlas must all be complete
  before the existing authoritative cue publishes. Cancellation retains every
  private identity/resource until its worker has ended.

The anti-slop implementer, correctness implementer and independent plan/anti-OOP
guard review these ownership changes. Native first-frame pixels, retained and
initial floor/actor/sight cases, cancellation, Studio seeking/looping and the full
door→movement→Haste→two Fireballs route remain required. Both readiness holds
must be below 50 ms (100 ms minimum); frame regressions remain unacceptable.
Do not count reduced work or overlap as achieved latency before the live result.

### Tested checkpoint requested by the user

The final construction lane uses one finite five-turn cursor over cookie,
light, actor, object and ground within the same2 ms account. Actor resource
work can begin before unrelated cookie/light completion; ready objects progress
even while actor work continues. Membership and exact canonical seal still
precede the authoritative world publication. Private source capture/style/output
finishes on the existing planner, with Nodes and live bindings on main. The
discarded wait-suppression cache is absent. The final actor metadata merge
overwrites the initial null shader stamp, avoiding redundant first-frame copies;
strict zero-copy assertions remain and actual live full copies fall47→0.

Final route `20261016T212402.703340Z` passes81 checks: door310.550 ms hold,
movement19.828, Fireballs53.740/36.895. Door target and no-spike objectives are
not achieved; movement publication52.273 ms and pre-onset draw sorting remain.
Full native Studio passes8,686 checks, actor305 headless/341 native with12
exact pairs; independent anti-slop/correctness/plan/anti-OOP reviewers found no
checkpoint ownership blocker. Known shutdown warnings and source-fixture limits
remain in the linked comprehensive handoff. At the user's explicit request,
stop after this tested coherent batch, preserve all failed/regressed timing
evidence, and commit. This does not mark the three-operation performance
objective complete or authorize another renderer/backend redesign.
